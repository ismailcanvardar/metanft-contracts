// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

abstract contract ExchangeEnums {
    string constant DIRECT_SALE = "DIRECT_SALE";
    string constant ENGLISH_AUCTION = "ENGLISH_AUCTION";
    string constant DUTCH_AUCTION = "DUTCH_AUCTION";

    enum ListingType {
        DIRECT_SALE,
        ENGLISH_AUCTION,
        DUTCH_AUCTION
    }
}