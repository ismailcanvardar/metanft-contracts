// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

library ExchangeTypes {
    string constant DIRECT_SALE = "DIRECT_SALE";
    string constant ENGLISH_AUCTION = "ENGLISH_AUCTION";
    string constant DUTCH_AUCTION = "DUTCH_AUCTION";

    enum ListingType {
        DIRECT_SALE,
        ENGLISH_AUCTION,
        DUTCH_AUCTION
    }

    struct Bid {
        address originAddress;
        uint256 tokenId;
        address bidder;
        uint256 bidAmount;
        bool isERC20;
        address erc20TokenAddress;
    }

    struct Listing {
        address originAddress;
        uint256 tokenId;
        address seller;
        uint256 startTimestamp;
        uint256 endTimestamp;
        uint256 softCap;
        uint256 hardCap;
        bool isERC20;
        address erc20TokenAddress;
        ListingType listingType;
    }
}
