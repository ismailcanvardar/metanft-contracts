// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../lib/RoyaltyFeeManagerStructs.sol";

interface IRoyaltyFeeManager {
    function getCreator(
        address originAddress,
        uint256 tokenId
    ) external view returns (address);

    function setCreator(
        address originAddress,
        uint256 tokenId
    ) external returns (bool);

    function getRoyaltyFeeConfig(
        address originAddress,
        uint256 tokenId
    ) external view returns (RoyaltyFeeManagerStructs.RoyaltyFeeConfig memory);

    function registerRoyaltyFeeConfig(
        address originAddress,
        uint256 tokenId,
        address newOwner,
        uint256 newFeePercentage,
        bool isOwnershipTransferable
    ) external returns (bool);

    function calculateRoyaltyFee(
        uint256 amount,
        uint256 feePercentage
    ) external pure returns (uint256);
}
