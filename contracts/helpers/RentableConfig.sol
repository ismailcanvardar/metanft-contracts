// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "../interfaces/IRentableConfig.sol";

/**
 * @title RentableConfig
 * @dev A contract for managing rentable configurations including maker and taker fee percentages.
 */
contract RentableConfig is Ownable2Step, IRentableConfig {
    uint8 public makerFeePercentage;
    uint8 public takerFeePercentage;
    uint8 public constant BASE_DIVIDER = 100;

    event SetMakerFeePercentage(uint256 percentage);
    event SetTakerFeePercentage(uint256 percentage);

    /**
     * @dev Constructor.
     * @param _makerFeePercentage The initial maker fee percentage.
     * @param _takerFeePercentage The initial taker fee percentage.
     */
    constructor(uint8 _makerFeePercentage, uint8 _takerFeePercentage) {
        _transferOwnership(_msgSender());

        makerFeePercentage = _makerFeePercentage;
        takerFeePercentage = _takerFeePercentage;
    }

    /**
     * @dev Sets the maker fee percentage.
     * @param newPercentage The new maker fee percentage to set.
     */
    function setMakerFeePercentage(uint8 newPercentage) external onlyOwner {
        makerFeePercentage = newPercentage;
    }

    /**
     * @dev Sets the taker fee percentage.
     * @param newPercentage The new taker fee percentage to set.
     */
    function setTakerFeePercentage(uint8 newPercentage) external onlyOwner {
        takerFeePercentage = newPercentage;
    }

    /**
     * @dev Calculates the fee amount and amount after deducting the fee based on the bid amount and the fee percentage.
     * @param bidAmount The bid amount.
     * @param isMaker A boolean indicating whether the bid is from a maker.
     * @return feeAmount The fee amount deducted from the bid amount.
     * @return amountAfterFee The amount remaining after deducting the fee.
     */
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

    /**
     * @dev Internal function to calculate the fee amount based on the given amount and percentage.
     * @param _amount The original amount.
     * @param _percentage The fee percentage.
     * @return The fee amount calculated based on the given amount and percentage.
     */
    function _calculateFee(
        uint256 _amount,
        uint8 _percentage
    ) internal pure returns (uint256) {
        return (_amount * _percentage) / BASE_DIVIDER;
    }
}
