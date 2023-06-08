// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IFractionalProxyManager {
    function fractionalize( address originAddress, 
        uint256 tokenId,
        string[] memory tokenURIs, 
        string memory name, 
        string memory symbol
    ) external returns(uint256);
}