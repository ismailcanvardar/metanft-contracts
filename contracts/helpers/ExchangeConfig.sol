// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "../interfaces/IExchangeConfig.sol";

contract ExchangeConfig is IExchangeConfig, Ownable2Step {
    uint8 private _EXCHANGE_FEE_PERCENTAGE = 5;
    uint8 private constant _BASE_DIVIDER = 100;

    event SetExchangeFeePercentage(uint256 percentage);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function getExchangeFeePercentage() external view override returns (uint8) {
        return _EXCHANGE_FEE_PERCENTAGE;
    }

    function setExchangeFeePercentage(uint8 _newPercentage) public onlyOwner {
        _EXCHANGE_FEE_PERCENTAGE = _newPercentage;

        emit SetExchangeFeePercentage(_newPercentage);
    }

    function calculateExchangeFee(
        uint256 amount
    ) external view returns (uint256) {
        return _calculateExchangeFee(amount);
    }

    function getAmountAfterFee(
        uint256 bidAmount
    )
        external
        view
        override
        returns (uint256 feeAmount, uint256 amountAfterFee)
    {
        uint256 calculatedFee = _calculateExchangeFee(bidAmount);
        return (calculatedFee, calculatedFee + bidAmount);
    }

    function _calculateExchangeFee(
        uint256 _amount
    ) internal view returns (uint256) {
        return (_amount * _EXCHANGE_FEE_PERCENTAGE) / _BASE_DIVIDER;
    }
}
