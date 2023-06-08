// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ExchangeEnums.sol";

abstract contract ExchangeStructs {
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
        ExchangeEnums.ListingType listingType;
    }
}
