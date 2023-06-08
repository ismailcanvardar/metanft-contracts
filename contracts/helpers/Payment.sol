// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IPayment.sol";

/**
 * @title Payment
 * @dev A contract that provides safe transfer functions for handling ETH and ERC20 token transfers.
 */
abstract contract Payment is IPayment {
    event SendETH(address from, address to, uint256 amount);
    event SendToken(
        address contractAddress,
        address from,
        address to,
        uint256 amount
    );

    /**
     * @dev Safely sends ETH from one address to another.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount of ETH to send.
     * @return A boolean indicating whether the ETH transfer was successful.
     */
    function safeSendETH(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(from != address(0), "safeSendETH: Invalid from address.");
        require(to != address(0), "safeSendETH: Invalid to address.");
        require(amount > 0, "safeSendETH: Invalid amount");

        return _sendETH(from, to, amount);
    }

    /**
     * @dev Safely sends ERC20 tokens from one address to another.
     * @param contractAddress The address of the ERC20 token contract.
     * @param from The sender address.
     * @param to The recipient address.
     * @param amount The amount of tokens to send.
     * @return A boolean indicating whether the token transfer was successful.
     */
    function safeSendToken(
        address contractAddress,
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        require(
            contractAddress != address(0),
            "safeSendToken: Invalid token contract address."
        );
        require(from != address(0), "safeSendToken: Invalid from address.");
        require(to != address(0), "safeSendToken: Invalid to address.");
        require(amount > 0, "safeSendToken: Invalid amount");

        _sendToken(contractAddress, from, to, amount);

        return true;
    }

    /**
     * @dev Internal function to safely send ETH from one address to another.
     * @param _from The sender address.
     * @param _to The recipient address.
     * @param _amount The amount of ETH to send.
     * @return A boolean indicating whether the ETH transfer was successful.
     */
    function _sendETH(
        address _from,
        address _to,
        uint256 _amount
    ) internal returns (bool) {
        (bool sent, ) = _to.call{value: _amount}("");

        require(sent, "_sendETH: Unable to send.");

        emit SendETH(_from, _to, _amount);
        return sent;
    }

    /**
     * @dev Internal function to safely send ERC20 tokens from one address to another.
     * @param _contractAddress The address of the ERC20 token contract.
     * @param _from The sender address.
     * @param _to The recipient address.
     * @param _amount The amount of tokens to send.
     */
    function _sendToken(
        address _contractAddress,
        address _from,
        address _to,
        uint256 _amount
    ) internal {
        IERC20 token = IERC20(_contractAddress);
        SafeERC20.safeTransferFrom(token, _from, _to, _amount);

        emit SendToken(_contractAddress, _from, _to, _amount);
    }
}
