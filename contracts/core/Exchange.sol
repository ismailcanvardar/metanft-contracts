// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "../interfaces/IAffiliate.sol";
import "../interfaces/IExchangeConfig.sol";
import "../interfaces/IRoyaltyFeeManager.sol";

import "../helpers/ExchangeConfig.sol";
import "../helpers/Payment.sol";

import "../lib/ExchangeEnums.sol";
import "../lib/ExchangeStructs.sol";
import "../lib/RoyaltyFeeManagerStructs.sol";

import "../utils/SignatureVerifier.sol";

contract Exchange is Payment, ReentrancyGuard, SignatureVerifier, Ownable2Step {
    address private _FEE_COLLECTOR;
    IAffiliate private _AFFILIATE;
    IExchangeConfig private _EXCHANGE_CONFIG;
    IRoyaltyFeeManager private _ROYALTY_FEE_MANAGER;
    address public WETH;

    event FinalizeAuction(
        address originAddress,
        uint256 tokenId,
        address seller,
        address bidder,
        bool status
    );
    event DirectBuy(
        address originAddress,
        uint256 tokenId,
        address seller,
        address buyer,
        bool status
    );
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
        _transferOwnership(_msgSender());

        _FEE_COLLECTOR = _feeCollector;
        _AFFILIATE = _affiliate;
        _EXCHANGE_CONFIG = _exchangeConfig;
        _ROYALTY_FEE_MANAGER = _royaltyFeeManager;
        WETH = _weth;
    }

    modifier onlySeller(address _itemOwner) {
        require(_msgSender() == _itemOwner);
        _;
    }

    modifier directBuyCompatible(ExchangeEnums.ListingType _listingType) {
        require(
            _listingType == ExchangeEnums.ListingType.DIRECT_SALE ||
                _listingType == ExchangeEnums.ListingType.DUTCH_AUCTION,
            "directBuyCompatible: Listing is not valid!"
        );
        _;
    }

    function getFeeCollector() public view returns (address) {
        return _FEE_COLLECTOR;
    }

    function getAffiliate() public view returns (IAffiliate) {
        return _AFFILIATE;
    }

    function getExchangeConfig() public view returns (IExchangeConfig) {
        return _EXCHANGE_CONFIG;
    }

    function getRoyaltyFeeManager() public view returns (IRoyaltyFeeManager) {
        return _ROYALTY_FEE_MANAGER;
    }

    function setFeeCollector(address newAddress) public onlyOwner {
        _FEE_COLLECTOR = newAddress;

        emit SetFeeCollector(newAddress);
    }

    function setAffiliate(IAffiliate newAddress) public onlyOwner {
        _AFFILIATE = newAddress;

        emit SetAffiliate(newAddress);
    }

    function setExchangeConfig(IExchangeConfig newAddress) public onlyOwner {
        _EXCHANGE_CONFIG = newAddress;

        emit SetExchangeConfig(newAddress);
    }

    function setRoyaltyFeeManager(
        IRoyaltyFeeManager newAddress
    ) public onlyOwner {
        _ROYALTY_FEE_MANAGER = newAddress;

        emit SetRoyaltyFeeManager(newAddress);
    }

    function directBuy(
        ExchangeStructs.Listing memory listing,
        bytes memory sig,
        uint256 nonce
    ) public payable nonReentrant directBuyCompatible(listing.listingType) {
        _verifyListing(sig, listing, nonce);

        uint256 buyAmount = listing.listingType ==
            ExchangeEnums.ListingType.DIRECT_SALE
            ? listing.softCap
            : listing.hardCap;

        if (listing.isERC20) {
            _payout(
                listing.originAddress,
                listing.tokenId,
                buyAmount,
                _msgSender(),
                listing.seller,
                _msgSender(),
                listing.erc20TokenAddress,
                false
            );
        } else {
            _payout(
                listing.originAddress,
                listing.tokenId,
                buyAmount,
                address(this),
                listing.seller,
                _msgSender(),
                address(0),
                true
            );
        }

        IERC721 erc721Instance = IERC721(listing.originAddress);
        require(
            erc721Instance.getApproved(listing.tokenId) == address(this),
            "directBuy: Approval needed for this action!"
        );

        erc721Instance.transferFrom(
            listing.seller,
            _msgSender(),
            listing.tokenId
        );

        emit DirectBuy(
            listing.originAddress,
            listing.tokenId,
            listing.seller,
            _msgSender(),
            true
        );
    }

    function finalizeAuction(
        ExchangeStructs.Listing memory listing,
        ExchangeStructs.Bid memory bid,
        bytes[2] memory sigs,
        uint256[2] memory nonces
    ) public nonReentrant onlySeller(listing.seller) {
        _verifyListing(sigs[0], listing, nonces[0]);
        _verifyBid(sigs[1], bid, nonces[1]);

        IERC721 erc721Instance = IERC721(listing.originAddress);
        require(
            erc721Instance.ownerOf(listing.tokenId) == _msgSender(),
            "finalizeAuction: Must be owner of the token!"
        );

        require(
            erc721Instance.getApproved(listing.tokenId) == address(this),
            "finalizeAuction: Approval needed for this action!"
        );

        require(
            bid.bidAmount > listing.softCap,
            "finalizeAuction: Bid amount must be bigger than softCap!"
        );

        require(
            block.timestamp > listing.startTimestamp,
            "finalizeAuction: Auction is not started yet!"
        );

        if (
            listing.listingType == ExchangeEnums.ListingType.ENGLISH_AUCTION ||
            listing.listingType == ExchangeEnums.ListingType.DUTCH_AUCTION
        ) {
            require(
                block.timestamp > listing.endTimestamp,
                "finalizeAuction: Auction is not ended, yet!"
            );
        }

        if (listing.erc20TokenAddress == address(0)) {
            _payout(
                listing.originAddress,
                listing.tokenId,
                bid.bidAmount,
                bid.bidder,
                listing.seller,
                bid.bidder,
                WETH,
                false
            );
        } else {
            _payout(
                listing.originAddress,
                listing.tokenId,
                bid.bidAmount,
                bid.bidder,
                listing.seller,
                bid.bidder,
                listing.erc20TokenAddress,
                false
            );
        }

        erc721Instance.transferFrom(
            listing.seller,
            bid.bidder,
            listing.tokenId
        );

        emit FinalizeAuction(
            listing.originAddress,
            listing.tokenId,
            listing.seller,
            bid.bidder,
            true
        );
    }

    function _getFees(
        address _originAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _invited
    )
        internal
        view
        returns (uint256[6] memory fees, address[2] memory addresses)
    {
        require(_amount > 0, "getFees: Amount must be bigger than zero!");

        fees[0] = _amount;

        uint256 exchangeFeeAmount = _EXCHANGE_CONFIG.calculateExchangeFee(
            _amount
        );
        fees[1] = exchangeFeeAmount;
        uint256 amountAfterExchangeFee = _amount + exchangeFeeAmount;
        fees[2] = amountAfterExchangeFee;

        address affiliateAddress = _AFFILIATE.getAffiliateAddress(_invited);
        if (affiliateAddress != address(0)) {
            (uint256 invitorFeeAmount, uint256 invitedFeeAmount) = _AFFILIATE
                .calculateAffiliateFees(exchangeFeeAmount);
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
        RoyaltyFeeManagerStructs.RoyaltyFeeConfig
            memory royaltyFeeConfig = _ROYALTY_FEE_MANAGER.getRoyaltyFeeConfig(
                _originAddress,
                _tokenId
            );
        if (royaltyFeeConfig.creator != address(0)) {
            uint256 royaltyFeeAmount = _ROYALTY_FEE_MANAGER.calculateRoyaltyFee(
                _amount,
                royaltyFeeConfig.feePercentage
            );
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
        (uint256[6] memory fees, address[2] memory addresses) = _getFees(
            _originAddress,
            _tokenId,
            _amount,
            _bidder
        );

        if (_isETHTransfer) {
            require(
                msg.value >= fees[2],
                "_payout: Sent amount is not correct!"
            );

            if (addresses[0] != address(0)) {
                Payment.safeSendETH(_fromAddress, addresses[0], fees[3]);
            }

            if (addresses[1] != address(0)) {
                Payment.safeSendETH(_fromAddress, addresses[1], fees[5]);
                Payment.safeSendETH(_fromAddress, _seller, fees[0] - fees[5]);
            } else {
                Payment.safeSendETH(_fromAddress, _seller, fees[0]);
            }

            Payment.safeSendETH(
                address(this),
                _FEE_COLLECTOR,
                fees[1] - fees[4] - fees[3]
            );
        } else {
            IERC20 erc20Instance = IERC20(_tokenAddress);
            require(
                erc20Instance.allowance(_bidder, address(this)) >= fees[2],
                "_payout: Needs to approve tokens!"
            );

            if (addresses[0] != address(0)) {
                Payment.safeSendToken(
                    _tokenAddress,
                    _fromAddress,
                    addresses[0],
                    fees[3]
                );
                Payment.safeSendToken(
                    _tokenAddress,
                    _fromAddress,
                    _bidder,
                    fees[4]
                );
            }

            if (addresses[1] != address(0)) {
                Payment.safeSendToken(
                    _tokenAddress,
                    _fromAddress,
                    addresses[1],
                    fees[5]
                );
                Payment.safeSendToken(
                    _tokenAddress,
                    _fromAddress,
                    _seller,
                    fees[0] - fees[5]
                );
            } else {
                Payment.safeSendToken(
                    _tokenAddress,
                    _fromAddress,
                    _seller,
                    fees[0]
                );
            }

            Payment.safeSendToken(
                _tokenAddress,
                _bidder,
                _FEE_COLLECTOR,
                fees[1] - fees[4] - fees[3]
            );
        }
    }
}
