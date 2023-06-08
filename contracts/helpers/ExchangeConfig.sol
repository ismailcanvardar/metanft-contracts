// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";

import "../interfaces/IExchangeConfig.sol";

/**
 * @title ExchangeConfig Contract
 * @dev A smart contract for managing the configuration of an exchange.
 * This contract provides functionality for setting and retrieving the exchange fee percentage,
 * as well as calculating the exchange fee for a given amount.
 */
contract ExchangeConfig is IExchangeConfig, Ownable2Step {
    uint8 private exchangeFeePercentage = 5;
    uint8 public constant BASE_DIVIDER = 100;

    event SetExchangeFeePercentage(uint256 percentage);

    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Returns the current exchange fee percentage.
     * @return The exchange fee percentage.
     */
    function getExchangeFeePercentage() external view override returns (uint8) {
        return exchangeFeePercentage;
    }

    /**
     * @dev Calculates the exchange fee for a given amount.
     * @param amount The amount for which to calculate the exchange fee.
     * @return The calculated exchange fee.
     */
    function calculateExchangeFee(
        uint256 amount
    ) external view returns (uint256) {
        return _calculateExchangeFee(amount);
    }

    /**
     * @dev Sets the exchange fee percentage.
     * Only the contract owner can call this function.
     * @param _newPercentage The new exchange fee percentage to set.
     */
    function setExchangeFeePercentage(uint8 _newPercentage) external onlyOwner {
        exchangeFeePercentage = _newPercentage;

        emit SetExchangeFeePercentage(_newPercentage);
    }

    /**
     * @dev Calculates the amount after deducting the exchange fee from the bid amount.
     * @param bidAmount The bid amount for which to calculate the amount after fee.
     * @return feeAmount The exchange fee amount.
     * @return amountAfterFee The amount after deducting the fee.
     */
    function getAmountAfterFee(
        uint256 bidAmount
    ) public view override returns (uint256 feeAmount, uint256 amountAfterFee) {
        uint256 calculatedFee = _calculateExchangeFee(bidAmount);
        return (calculatedFee, calculatedFee + bidAmount);
    }

    /**
     * @dev Internal function to calculate the exchange fee for a given amount.
     * @param _amount The amount for which to calculate the exchange fee.
     * @return The calculated exchange fee.
     */
    function _calculateExchangeFee(
        uint256 _amount
    ) internal view returns (uint256) {
        return (_amount * exchangeFeePercentage) / BASE_DIVIDER;
    }
}
