// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../lib/ExchangeEnums.sol";
import "../lib/ExchangeStructs.sol";

/**
 * @title SignatureVerifier
 * @dev Contract for verifying signatures used in the exchange.
 */
abstract contract SignatureVerifier {
    using ECDSA for bytes32;

    mapping(bytes => bool) private usedSignatures;

    bytes32 public DOMAIN_SEPARATOR;

    bytes32 public constant BID_TYPEHASH =
        keccak256(
            "Bid(address originAddress,uint256 tokenId,address bidder,uint256 bidAmount,bool isERC20,address erc20TokenAddress,uint256 nonce)"
        );
    bytes32 public constant LISTING_TYPEHASH =
        keccak256(
            "Listing(address originAddress,uint256 tokenId,address seller,uint256 startTimestamp,uint256 endTimestamp,uint256 softCap,uint256 hardCap,bool isERC20,address erc20TokenAddress,uint256 listingType,uint256 nonce)"
        );

    event UseSignature(bytes signature, bool status);

    constructor() {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("Metatime")),
                keccak256(bytes("1.0")),
                block.chainid,
                address(this)
            )
        );
    }

    /**
     * @dev Check if a signature has been used before.
     * @param signature The signature to check.
     * @return bool indicating whether the signature has been used before.
     */
    function checkSignature(bytes memory signature) public view returns (bool) {
        return usedSignatures[signature];
    }

    /**
     * @dev Mark a signature as used.
     * @param signature The signature to mark as used.
     */
    function _useSignature(bytes memory signature) internal {
        usedSignatures[signature] = true;
    }

    /**
     * @dev Verify the signature of a listing.
     * @param _signature The signature to verify.
     * @param _listing The Listing struct representing the listing.
     * @param _nonce The nonce associated with the signature.
     */
    function _verifyListing(
        bytes memory _signature,
        ExchangeStructs.Listing memory _listing,
        uint256 _nonce
    ) internal {
        require(
            usedSignatures[_signature] == false,
            "_verifyListing: This signature is used before!"
        );
        bytes32 digest = ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR,
            keccak256(
                abi.encode(
                    LISTING_TYPEHASH,
                    _listing.originAddress,
                    _listing.tokenId,
                    _listing.seller,
                    _listing.startTimestamp,
                    _listing.endTimestamp,
                    _listing.softCap,
                    _listing.hardCap,
                    _listing.isERC20,
                    _listing.erc20TokenAddress,
                    _listing.listingType,
                    _nonce
                )
            )
        );
        address recoveredAddress = digest.recover(_signature);
        require(
            recoveredAddress == _listing.seller,
            "_verifyListing: Invalid Signature."
        );
        _useSignature(_signature);
    }

    /**
     * @dev Verify the signature of a bid.
     * @param _signature The signature to verify.
     * @param _bid The Bid struct representing the bid.
     * @param _nonce The nonce associated with the signature.
     */
    function _verifyBid(
        bytes memory _signature,
        ExchangeStructs.Bid memory _bid,
        uint256 _nonce
    ) internal {
        require(
            usedSignatures[_signature] == false,
            "_verifyBid: This signature is used before!"
        );
        bytes32 digest = ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR,
            keccak256(
                abi.encode(
                    BID_TYPEHASH,
                    _bid.originAddress,
                    _bid.tokenId,
                    _bid.bidder,
                    _bid.bidAmount,
                    _bid.isERC20,
                    _bid.erc20TokenAddress,
                    _nonce
                )
            )
        );
        address recoveredAddress = digest.recover(_signature);
        require(
            recoveredAddress == _bid.bidder,
            "_verifyBid: Invalid Signature."
        );
        _useSignature(_signature);
    }
}
