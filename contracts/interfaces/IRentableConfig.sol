// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IRentableConfig {
    function getAmountAfterFee(
        uint256 bidAmount,
        bool isMaker
    ) external view returns (uint256 feeAmount, uint256 amountAfterFee);
}
