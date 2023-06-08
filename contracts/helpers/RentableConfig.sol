// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../interfaces/IRentableConfig.sol";

contract RentableConfig is Ownable, IRentableConfig {
    // Satıcı komisyonu
    uint8 private _MAKER_FEE_PERCENTAGE;
    // Alıcı komisyonu
    uint8 private _TAKER_FEE_PERCENTAGE;
    // Yüzdelik hesaplamak için bölen değer
    uint8 private constant _BASE_DIVIDER = 100;

    event SetMakerFeePercentage(uint256 percentage);
    event SetTakerFeePercentage(uint256 percentage);

    constructor(uint8 _makerFeePercentage, uint8 _takerFeePercentage) {
        _MAKER_FEE_PERCENTAGE = _makerFeePercentage;
        _TAKER_FEE_PERCENTAGE = _takerFeePercentage;
    }

    function getFees() external view override returns (uint8[2] memory) {
        return [_MAKER_FEE_PERCENTAGE, _TAKER_FEE_PERCENTAGE];
    }

    function setMakerFeePercentage(uint8 newPercentage) public onlyOwner {
        _MAKER_FEE_PERCENTAGE = newPercentage;
    }

    function setTakerFeePercentage(uint8 newPercentage) public onlyOwner {
        _TAKER_FEE_PERCENTAGE = newPercentage;
    }

    function getAmountAfterFee(
        uint256 bidAmount,
        bool isMaker
    )
        external
        view
        override
        returns (uint256 feeAmount, uint256 amountAfterFee)
    {
        uint256 calculatedFee;

        if (isMaker) {
            calculatedFee = _calculateFee(bidAmount, _MAKER_FEE_PERCENTAGE);
        } else {
            calculatedFee = _calculateFee(bidAmount, _TAKER_FEE_PERCENTAGE);
        }

        return (calculatedFee, calculatedFee + bidAmount);
    }

    function _calculateFee(
        uint256 _amount,
        uint8 _percentage
    ) internal pure returns (uint256) {
        return (_amount * _percentage) / _BASE_DIVIDER;
    }
}
