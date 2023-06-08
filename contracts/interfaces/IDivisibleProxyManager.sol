// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IDivisibleProxyManager {
    function divide(address originAddress, uint256 tokenId, uint256 totalSupply, string memory name, string memory symbol) external returns(uint256);
}