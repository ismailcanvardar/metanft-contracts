// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "../interfaces/IExchangeConfig.sol";

contract ExchangeConfig is IExchangeConfig, Ownable2Step {
    uint8 private exchangeFeePercentage = 5;
    uint8 public constant BASE_DIVIDER = 100;

    event SetExchangeFeePercentage(uint256 percentage);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function getExchangeFeePercentage() external view override returns (uint8) {
        return exchangeFeePercentage;
    }

    function calculateExchangeFee(
        uint256 amount
    ) external view returns (uint256) {
        return _calculateExchangeFee(amount);
    }

    function setExchangeFeePercentage(uint8 _newPercentage) external onlyOwner {
        exchangeFeePercentage = _newPercentage;

        emit SetExchangeFeePercentage(_newPercentage);
    }

    function getAmountAfterFee(
        uint256 bidAmount
    ) public view override returns (uint256 feeAmount, uint256 amountAfterFee) {
        uint256 calculatedFee = _calculateExchangeFee(bidAmount);
        return (calculatedFee, calculatedFee + bidAmount);
    }

    function _calculateExchangeFee(
        uint256 _amount
    ) internal view returns (uint256) {
        return (_amount * exchangeFeePercentage) / BASE_DIVIDER;
    }
}
