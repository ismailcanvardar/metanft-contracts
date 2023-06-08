// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract RoyaltyFeeManagerStructs {
    struct RoyaltyFeeConfig {
        address creator;
        uint256 feePercentage;
        bool isOwnershipTransferable;
    }
}
