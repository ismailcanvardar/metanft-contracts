// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "./Fractional.sol";
import "../interfaces/IFractionalProxyManager.sol";

/**
 * @title FractionalProxyManager
 * @dev A contract for managing the fractionalization of ERC721 tokens.
 * The contract allows the curator to fractionalize an ERC721 token into multiple fractional tokens with unique tokenURIs.
 */
contract FractionalProxyManager is Ownable2Step, IFractionalProxyManager {
    uint256 public fractionalCount;

    mapping(uint256 => address) public fractionals;
    mapping(address => bool) public fractionalWhitelist;

    address public immutable logic;

    event Fractionalize(
        address indexed curator,
        address originAddress,
        uint256 tokenId,
        address fractional,
        uint256 fractionalId
    );

    constructor() {
        _transferOwnership(_msgSender());

        logic = address(new Fractional());
    }

    /**
     * @dev Adds a fractional proxy address to the whitelist.
     * @param proxyAddress The address of the fractional proxy contract.
     * @return A boolean indicating whether the addition was successful.
     */
    function addToWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        fractionalWhitelist[proxyAddress] = true;

        return true;
    }

    /**
     * @dev Removes a fractional proxy address from the whitelist.
     * @param proxyAddress The address of the fractional proxy contract.
     * @return A boolean indicating whether the removal was successful.
     */
    function removeFromWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        fractionalWhitelist[proxyAddress] = false;

        return true;
    }

    /**
     * @dev Fractionalizes an ERC721 token.
     * @param originAddress The address of the original ERC721 contract.
     * @param tokenId The ID of the original ERC721 token.
     * @param tokenURIs An array of tokenURIs for the fractional tokens.
     * @param name The name of the fractional token.
     * @param symbol The symbol of the fractional token.
     * @return The ID of the fractional token.
     */
    function fractionalize(
        address originAddress,
        uint256 tokenId,
        string[] memory tokenURIs,
        string memory name,
        string memory symbol
    ) external override returns (uint256) {
        bytes memory _initializationCalldata = abi.encodeWithSignature(
            "initialize(address,address,uint256,string[],string,string)",
            _msgSender(),
            originAddress,
            tokenId,
            tokenURIs,
            name,
            symbol
        );

        address fractionalProxy = address(
            new InitializedProxy(logic, _initializationCalldata)
        );

        emit Fractionalize(
            _msgSender(),
            originAddress,
            tokenId,
            fractionalProxy,
            fractionalCount
        );

        IERC721(originAddress).safeTransferFrom(
            _msgSender(),
            fractionalProxy,
            tokenId
        );

        fractionals[fractionalCount] = fractionalProxy;
        fractionalCount++;

        fractionalWhitelist[fractionalProxy] = true;

        return fractionalCount - 1;
    }
}
