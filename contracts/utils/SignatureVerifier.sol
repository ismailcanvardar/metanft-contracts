// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import "../lib/ExchangeEnums.sol";
import "../lib/ExchangeStructs.sol";

abstract contract SignatureVerifier {
    using ECDSA for bytes32;

    // Kullanılan imzaları tutar, böylelikle bir imza birden çok kez kullanılmaz.
    mapping(bytes => bool) private usedSignatures;

    bytes32 public DOMAIN_SEPARATOR;

    bytes32 public constant BID_TYPEHASH = keccak256("Bid(address originAddress,uint256 tokenId,address bidder,uint256 bidAmount,bool isERC20,address erc20TokenAddress,uint256 nonce)");
    bytes32 public constant LISTING_TYPEHASH = keccak256("Listing(address originAddress,uint256 tokenId,address seller,uint256 startTimestamp,uint256 endTimestamp,uint256 softCap,uint256 hardCap,bool isERC20,address erc20TokenAddress,uint256 listingType,uint256 nonce)");

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

    // İmzanın aktifliğini kontrol eder
    function checkSignature(bytes memory signature) public view returns(bool) {
        return usedSignatures[signature];
    }

    // İmzayı kullanılmış statüsüne çeker
    function _useSignature(bytes memory signature) internal {
        usedSignatures[signature] = true;
    }

    // Kullanıcının sağladığı _listing değerleri ile tip hashlerini birleştirip hashler, 
    // sonrasında kullanıcının yolladığı imza ile karşılaştırıp dönen adresle karşılaştırır 
    function _verifyListing(bytes memory _signature, ExchangeStructs.Listing memory _listing, uint256 _nonce) internal {
        require(usedSignatures[_signature] == false, "_verifyListing: This signature is used before!");
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
        require(recoveredAddress == _listing.seller, "_verifyListing: Invalid Signature.");
        _useSignature(_signature);
    }

    // _verifyListing ile aynı işlemi yapar, farkı _bid yapısıyla imzayı karşılaştırması
    function _verifyBid(bytes memory _signature, ExchangeStructs.Bid memory _bid, uint256 _nonce) internal {
        require(usedSignatures[_signature] == false, "_verifyBid: This signature is used before!");
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
        require(recoveredAddress == _bid.bidder, "_verifyBid: Invalid Signature.");
        _useSignature(_signature);
    }
}
