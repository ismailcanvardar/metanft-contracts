// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IRentableConfig {
    function getFees() external view returns(uint8[2] memory);
    function getAmountAfterFee(uint256 bidAmount, bool isMaker) external view returns(uint256 feeAmount, uint256 amountAfterFee);
}