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

/**
 * @title Exchange
 * @dev A decentralized exchange contract for trading ERC721 and ERC20 tokens.
 */
contract Exchange is Payment, ReentrancyGuard, SignatureVerifier, Ownable2Step {
    address public feeCollector;
    IAffiliate public affiliate;
    IExchangeConfig public exchangeConfig;
    IRoyaltyFeeManager public royaltyFeeManager;
    address public immutable weth;

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

    /**
     * @dev Initializes the Exchange contract.
     * @param _feeCollector The address to receive exchange fees.
     * @param _affiliate The affiliate contract address.
     * @param _exchangeConfig The exchange configuration contract address.
     * @param _royaltyFeeManager The royalty fee manager contract address.
     * @param _weth The wrapped Ether token address.
     */
    constructor(
        address _feeCollector,
        IAffiliate _affiliate,
        IExchangeConfig _exchangeConfig,
        IRoyaltyFeeManager _royaltyFeeManager,
        address _weth
    ) {
        _transferOwnership(_msgSender());

        feeCollector = _feeCollector;
        affiliate = _affiliate;
        exchangeConfig = _exchangeConfig;
        royaltyFeeManager = _royaltyFeeManager;
        weth = _weth;
    }

    // Modifier to restrict function access to the seller
    modifier onlySeller(address _itemOwner) {
        require(_msgSender() == _itemOwner);
        _;
    }

    // Modifier to restrict function access to compatible listing types (direct sale and dutch auction)
    modifier directBuyCompatible(ExchangeEnums.ListingType _listingType) {
        require(
            _listingType == ExchangeEnums.ListingType.DIRECT_SALE ||
                _listingType == ExchangeEnums.ListingType.DUTCH_AUCTION,
            "directBuyCompatible: Listing is not valid!"
        );
        _;
    }

    /**
     * @dev Sets the fee collector address.
     * @param newAddress The new fee collector address.
     */
    function setFeeCollector(address newAddress) external onlyOwner {
        feeCollector = newAddress;

        emit SetFeeCollector(newAddress);
    }

    /**
     * @dev Sets the affiliate contract address.
     * @param newAddress The new affiliate contract address.
     */
    function setAffiliate(IAffiliate newAddress) external onlyOwner {
        affiliate = newAddress;

        emit SetAffiliate(newAddress);
    }

    /**
     * @dev Sets the exchange configuration contract address.
     * @param newAddress The new exchange configuration contract address.
     */
    function setExchangeConfig(IExchangeConfig newAddress) external onlyOwner {
        exchangeConfig = newAddress;

        emit SetExchangeConfig(newAddress);
    }

    /**
     * @dev Sets the royalty fee manager contract address.
     * @param newAddress The new royalty fee manager contract address.
     */
    function setRoyaltyFeeManager(
        IRoyaltyFeeManager newAddress
    ) external onlyOwner {
        royaltyFeeManager = newAddress;

        emit SetRoyaltyFeeManager(newAddress);
    }

    /**
     * @dev Handles the direct buy of an item.
     * @param listing The listing information of the item.
     * @param sig The signature to verify the listing.
     * @param nonce The nonce used to generate the signature.
     */
    function directBuy(
        ExchangeStructs.Listing memory listing,
        bytes memory sig,
        uint256 nonce
    ) external payable nonReentrant directBuyCompatible(listing.listingType) {
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

    /**
     * @dev Finalizes an auction by transferring the item to the highest bidder.
     * @param listing The listing information of the item.
     * @param bid The bid information of the highest bidder.
     * @param sigs The signatures to verify the listing and bid.
     * @param nonces The nonces used to generate the signatures.
     */
    function finalizeAuction(
        ExchangeStructs.Listing memory listing,
        ExchangeStructs.Bid memory bid,
        bytes[2] memory sigs,
        uint256[2] memory nonces
    ) external nonReentrant onlySeller(listing.seller) {
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
                weth,
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

    /**
     * @dev Internal function to calculate the fees for a transaction.
     * @param _originAddress The address of the token's contract.
     * @param _tokenId The ID of the token.
     * @param _amount The transaction amount.
     * @param _invited The address of the invited user (optional).
     * @return fees The array of fee amounts.
     * @return addresses The array of recipient addresses for the fees.
     */
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

        uint256 exchangeFeeAmount = exchangeConfig.calculateExchangeFee(
            _amount
        );
        fees[1] = exchangeFeeAmount;
        uint256 amountAfterExchangeFee = _amount + exchangeFeeAmount;
        fees[2] = amountAfterExchangeFee;

        address affiliateAddress = affiliate.getAffiliateAddress(_invited);
        if (affiliateAddress != address(0)) {
            (uint256 invitorFeeAmount, uint256 invitedFeeAmount) = affiliate
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
            memory royaltyFeeConfig = royaltyFeeManager.getRoyaltyFeeConfig(
                _originAddress,
                _tokenId
            );
        if (royaltyFeeConfig.creator != address(0)) {
            uint256 royaltyFeeAmount = royaltyFeeManager.calculateRoyaltyFee(
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

    /**
     * @dev Internal function to handle the payout of tokens.
     * @param _originAddress The address of the token's contract.
     * @param _tokenId The ID of the token.
     * @param _amount The transaction amount.
     * @param _fromAddress The recipient address.
     * @param _seller The seller address.
     * @param _bidder The buyer address.
     * @param _tokenAddress The address of the token to payout (address(0) for ETH).
     * @param _isETHTransfer Whether the token is ERC721 or not.
     */
    function _payout(
        address _originAddress,
        uint256 _tokenId,
        uint256 _amount,
        address _fromAddress,
        address _seller,
        address _bidder,
        address _tokenAddress,
        bool _isETHTransfer
    ) private {
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
                feeCollector,
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
                feeCollector,
                fees[1] - fees[4] - fees[3]
            );
        }
    }
}
