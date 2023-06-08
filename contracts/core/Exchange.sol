// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IAffiliate.sol";
import "../interfaces/IExchangeConfig.sol";
import "../interfaces/IRoyaltyFeeManager.sol";

import "../helpers/ExchangeConfig.sol";
import "../helpers/Payment.sol";

import "../lib/ExchangeEnums.sol";
import "../lib/ExchangeStructs.sol";
import "../lib/RoyaltyFeeManagerStructs.sol";

import "../utils/SignatureVerifier.sol";

/// @author Metatime
/// @title Exchange
contract Exchange is Payment, ReentrancyGuard, SignatureVerifier, Ownable {
    address private _FEE_COLLECTOR;
    IAffiliate private _AFFILIATE;
    IExchangeConfig private _EXCHANGE_CONFIG;
    IRoyaltyFeeManager private _ROYALTY_FEE_MANAGER;
    address public WETH;

    event FinalizeAuction(address originAddress, uint256 tokenId, address seller, address bidder, bool status);
    event DirectBuy(address originAddress, uint256 tokenId, address seller, address buyer, bool status);
    event SetFeeCollector(address newAddress);
    event SetAffiliate(IAffiliate newAddress);
    event SetExchangeConfig(IExchangeConfig newAddress);
    event SetRoyaltyFeeManager(IRoyaltyFeeManager newAddress);

    constructor(
        address _feeCollector, 
        IAffiliate _affiliate, 
        IExchangeConfig _exchangeConfig, 
        IRoyaltyFeeManager _royaltyFeeManager,
        address _weth
    ) {
        _FEE_COLLECTOR = _feeCollector;
        _AFFILIATE = _affiliate;
        _EXCHANGE_CONFIG = _exchangeConfig;
        _ROYALTY_FEE_MANAGER = _royaltyFeeManager;
        WETH = _weth;
    }

    // Kullanıcının gerçekten ürünün sahibi olup olmadığını kontrol et
    modifier onlySeller(address _itemOwner) {
        require(msg.sender == _itemOwner);
        _;
    }

    // Direct buy için kullanılabilir listeleme tiplerine bakar
    modifier directBuyCompatible(ExchangeEnums.ListingType _listingType) {
        require(_listingType == ExchangeEnums.ListingType.DIRECT_SALE || _listingType == ExchangeEnums.ListingType.DUTCH_AUCTION, "directBuyCompatible: Listing is not valid!");
        _;
    }

    // FeeCollector adresini getirir
    function getFeeCollector() public view returns(address) {
        return _FEE_COLLECTOR;
    }

    // Affiliate adresini getirir
    function getAffiliate() public view returns(IAffiliate) {
        return _AFFILIATE;
    }

    // ExchangeConfig kontrat adresini döndürür
    function getExchangeConfig() public view returns(IExchangeConfig) {
        return _EXCHANGE_CONFIG;
    }

    // RoyaltyFeeManager adresini getirir
    function getRoyaltyFeeManager() public view returns(IRoyaltyFeeManager) {
        return _ROYALTY_FEE_MANAGER;
    }

    // FeeCollector adresini değiştirir 
    function setFeeCollector(address newAddress) public onlyOwner {
        _FEE_COLLECTOR = newAddress;
        
        emit SetFeeCollector(newAddress);
    }

    // Affiliate adresini değiştirir 
    function setAffiliate(IAffiliate newAddress) public onlyOwner {
        _AFFILIATE = newAddress;

        emit SetAffiliate(newAddress);
    }

    // ExchangeConfig adresini değiştirir 
    function setExchangeConfig(IExchangeConfig newAddress) public onlyOwner {
        _EXCHANGE_CONFIG = newAddress;

        emit SetExchangeConfig(newAddress);
    }

    // RoyaltyFeeManager adresini değiştirir 
    function setRoyaltyFeeManager(IRoyaltyFeeManager newAddress) public onlyOwner {
        _ROYALTY_FEE_MANAGER = newAddress;

        emit SetRoyaltyFeeManager(newAddress);
    }

    // Dutch auction veya direkt listeleme tiplerinde kullanılabilen fonksiyon
    function directBuy(
        ExchangeStructs.Listing memory listing, 
        bytes memory sig,
        uint256 nonce
    ) public payable nonReentrant directBuyCompatible(listing.listingType) {        
        // Listelemeyi doğrula
        _verifyListing(sig, listing, nonce);

        uint256 buyAmount = listing.listingType == ExchangeEnums.ListingType.DIRECT_SALE ? listing.softCap : listing.hardCap;

        // Listeleme birimini kontrol et
        // ERC20 ile listelendiyse, approve miktarını market komisyonu + gönderilen miktardan büyük olduğunu kontrol et
        if (listing.isERC20) {
            _payout(listing.originAddress, listing.tokenId, buyAmount, msg.sender, listing.seller, msg.sender, listing.erc20TokenAddress, false);
        } else {
            _payout(listing.originAddress, listing.tokenId, buyAmount, address(this), listing.seller, msg.sender, address(0), true);
        }

        // Satıcının satmak istediği ürün sahipliğini devrettiğini kontrol et
        IERC721 erc721Instance = IERC721(listing.originAddress);
        require(erc721Instance.getApproved(listing.tokenId) == address(this), "directBuy: Approval needed for this action!");

        // Ürünü satıcıya gönder
        erc721Instance.transferFrom(listing.seller, msg.sender, listing.tokenId);

        emit DirectBuy(listing.originAddress, listing.tokenId, listing.seller, msg.sender, true);
    }

    // TODO: Kontrolleri fonksiyon veya modifier olarak parçala
    function finalizeAuction(
        ExchangeStructs.Listing memory listing, 
        ExchangeStructs.Bid memory bid, 
        bytes[2] memory sigs, 
        uint256[2] memory nonces
    ) 
        nonReentrant
        onlySeller(listing.seller)
        public 
    {
        // Satıcının gerçek satıcı olduğunu kontrol et (✓)
        _verifyListing(sigs[0], listing, nonces[0]);
        _verifyBid(sigs[1], bid, nonces[1]);

        // Satıcının satılan ürüne sahipliğini kontrol et
        IERC721 erc721Instance = IERC721(listing.originAddress);
        require(erc721Instance.ownerOf(listing.tokenId) == msg.sender, "finalizeAuction: Must be owner of the token!");

        // TODO: Test edilmesi gerekiyor
        // Satıcının satmak istediği ürün sahipliğini devrettiğini kontrol et
        require(erc721Instance.getApproved(listing.tokenId) == address(this), "finalizeAuction: Approval needed for this action!");

        // Bid amount must be bigger than soft cap
        require(bid.bidAmount > listing.softCap, "finalizeAuction: Bid amount must be bigger than softCap!");
 
        // Listelemenin aktif olduğunu kontrol et
        require(block.timestamp > listing.startTimestamp, "finalizeAuction: Auction is not started yet!");

        // English ve dutch auction için listelemenin bittiğini kontrol et
        if (listing.listingType == ExchangeEnums.ListingType.ENGLISH_AUCTION || listing.listingType == ExchangeEnums.ListingType.DUTCH_AUCTION) {
            require(block.timestamp > listing.endTimestamp, "finalizeAuction: Auction is not ended, yet!");
        }

        if (listing.erc20TokenAddress == address(0)) {
            _payout(listing.originAddress, listing.tokenId, bid.bidAmount, bid.bidder, listing.seller, bid.bidder, WETH, false);
        } else {
            _payout(listing.originAddress, listing.tokenId, bid.bidAmount, bid.bidder, listing.seller, bid.bidder, listing.erc20TokenAddress, false);
        }

        erc721Instance.transferFrom(listing.seller, bid.bidder, listing.tokenId);

        emit FinalizeAuction(listing.originAddress, listing.tokenId, listing.seller, bid.bidder, true);
    }

    // Fees: 
    // uint256 amount,
    // uint256 exchangeFeeAmount,
    // uint256 amountAfterExchangeFee,
    // uint256 invitorFeeAmount,
    // uint256 invitedFeeAmount,
    // uint256 royaltyFeeAmount,
    // Addresses:
    // address affiliateAddress,
    // address royaltyFeeConfigCreator,
    function _getFees(
        address _originAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _invited
    ) internal view returns(
        uint256[6] memory fees,
        address[2] memory addresses
    ) {
        require(_amount > 0, "getFees: Amount must be bigger than zero!");

        fees[0] = _amount;

        uint256 exchangeFeeAmount = _EXCHANGE_CONFIG.calculateExchangeFee(_amount);
        fees[1] = exchangeFeeAmount;
        uint256 amountAfterExchangeFee = _amount + exchangeFeeAmount;
        fees[2] = amountAfterExchangeFee;

        // Affiliate kontrolu yap
        address affiliateAddress = _AFFILIATE.getAffiliateAddress(_invited);
        if (affiliateAddress != address(0)) {
            (uint256 invitorFeeAmount, uint256 invitedFeeAmount) = _AFFILIATE.calculateAffiliateFees(exchangeFeeAmount);
            fees[3] = invitorFeeAmount;
            fees[4] = invitedFeeAmount;
            addresses[1] = affiliateAddress;
        } else {
            uint256 invitorFeeAmount = 0;
            uint256 invitedFeeAmount = 0;
            fees[3] = invitorFeeAmount;
            fees[4] = invitedFeeAmount;
            addresses[0] = affiliateAddress;
        }
        // RoyaltyFee kontrolu yap
        RoyaltyFeeManagerStructs.RoyaltyFeeConfig memory royaltyFeeConfig = _ROYALTY_FEE_MANAGER.getRoyaltyFeeConfig(_originAddress, _tokenId);
        if (royaltyFeeConfig.creator != address(0)) {
            uint256 royaltyFeeAmount = _ROYALTY_FEE_MANAGER.calculateRoyaltyFee(_amount, royaltyFeeConfig.feePercentage);
            address royaltyFeeConfigCreator = royaltyFeeConfig.creator;
            fees[5] = royaltyFeeAmount;
            addresses[1] = royaltyFeeConfigCreator;
        } else {
            uint256 royaltyFeeAmount = 0;
            address royaltyFeeConfigCreator = address(0);
            fees[5] = royaltyFeeAmount;
            addresses[1] = royaltyFeeConfigCreator;
        }
    }

    function _payout(
        address _originAddress, 
        uint256 _tokenId, 
        uint256 _amount, 
        address _fromAddress,
        address _seller,
        address _bidder,
        address _tokenAddress,
        bool _isETHTransfer
    ) internal {
        (
            uint256[6] memory fees,
            address[2] memory addresses
        ) = _getFees(
            _originAddress,
            _tokenId, 
            _amount,
            _bidder
        );

        if (_isETHTransfer) {
            // Gönderilen miktarın, komisyon + alınmak istenilen miktardan fazla olduğunu kontrol et
            require(msg.value >= fees[2], "_payout: Sent amount is not correct!");

            if (addresses[0] != address(0)) {
                // Invited user'a affiliate komisyonu aktar
                Payment.safeSendETH(_fromAddress, addresses[0], fees[3]);
            }

            if (addresses[1] != address(0)) {
                // Royalty fee miktarini token creator'a gonder
                Payment.safeSendETH(_fromAddress, addresses[1], fees[5]);
                // Satıcıya gönderilen miktarı yolla
                Payment.safeSendETH(_fromAddress, _seller, fees[0] - fees[5]);
            } else {
                // Satıcıya gönderilen miktarı yolla
                Payment.safeSendETH(_fromAddress, _seller, fees[0]);
            }

            // FeeCollector adresine komisyonu gönder
            Payment.safeSendETH(address(this), _FEE_COLLECTOR, fees[1] - fees[4] - fees[3]);
        } else {
            IERC20 erc20Instance = IERC20(_tokenAddress);
            require(erc20Instance.allowance(_bidder, address(this)) >= fees[2], "_payout: Needs to approve tokens!");
            
            if (addresses[0] != address(0)) {
                // Invited user'a affiliate komisyonu aktar
                Payment.safeSendToken(_tokenAddress, _fromAddress, addresses[0], fees[3]);
                // Invited user'a affiliate komisyonu aktar
                Payment.safeSendToken(_tokenAddress, _fromAddress, _bidder, fees[4]);
            }

            if (addresses[1] != address(0)) {
                // Royalty fee miktarini token creator'a gonder
                Payment.safeSendToken(_tokenAddress, _fromAddress, addresses[1], fees[5]);
                // Satıcıya token miktarını gönder
                Payment.safeSendToken(_tokenAddress, _fromAddress, _seller, fees[0] - fees[5]);
            } else {
                // Satıcıya token miktarını gönder
                Payment.safeSendToken(_tokenAddress, _fromAddress, _seller, fees[0]);
            }

            // FeeCollector kontratına komisyonu aktar
            Payment.safeSendToken(_tokenAddress, _bidder, _FEE_COLLECTOR, fees[1] - fees[4] - fees[3]);
        }
    }
}