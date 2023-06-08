// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IExchangeConfig {
    function getExchangeFeePercentage() external view returns (uint16);

    function calculateExchangeFee(
        uint256 amount
    ) external view returns (uint256);

    function getAmountAfterFee(
        uint256 bidAmount
    ) external view returns (uint256 feeAmount, uint256 amountAfterFee);
}
