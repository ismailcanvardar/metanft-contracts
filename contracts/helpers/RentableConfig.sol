// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "../interfaces/IRentableConfig.sol";

contract RentableConfig is Ownable2Step, IRentableConfig {
    uint8 public makerFeePercentage;
    uint8 public takerFeePercentage;
    uint8 public constant BASE_DIVIDER = 100;

    event SetMakerFeePercentage(uint256 percentage);
    event SetTakerFeePercentage(uint256 percentage);

    constructor(uint8 _makerFeePercentage, uint8 _takerFeePercentage) {
        _transferOwnership(_msgSender());

        makerFeePercentage = _makerFeePercentage;
        takerFeePercentage = _takerFeePercentage;
    }

    function setMakerFeePercentage(uint8 newPercentage) external onlyOwner {
        makerFeePercentage = newPercentage;
    }

    function setTakerFeePercentage(uint8 newPercentage) external onlyOwner {
        takerFeePercentage = newPercentage;
    }

    function getAmountAfterFee(
        uint256 bidAmount,
        bool isMaker
    ) public view override returns (uint256 feeAmount, uint256 amountAfterFee) {
        uint256 calculatedFee;

        if (isMaker) {
            calculatedFee = _calculateFee(bidAmount, makerFeePercentage);
        } else {
            calculatedFee = _calculateFee(bidAmount, takerFeePercentage);
        }

        return (calculatedFee, calculatedFee + bidAmount);
    }

    function _calculateFee(
        uint256 _amount,
        uint8 _percentage
    ) internal pure returns (uint256) {
        return (_amount * _percentage) / BASE_DIVIDER;
    }
}
