// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "./Divisible.sol";
import "../interfaces/IDivisibleProxyManager.sol";

/**
 * @title DivisibleProxyManager
 * @dev A contract for managing Divisible proxies and dividing ERC721 tokens into multiple divisible tokens.
 * The contract allows the owner to add or remove proxy contracts from the whitelist and create divisible proxy contracts associated with divided tokens.
 */
contract DivisibleProxyManager is Ownable2Step, IDivisibleProxyManager {
    uint256 public divisibleCount;

    mapping(uint256 => address) public divisibles;
    mapping(address => bool) public divisibleWhitelist;

    address public immutable logic;

    event Divide(
        address indexed curator,
        address originAddress,
        uint256 tokenId,
        address divisible,
        uint256 divisibleId
    );

    constructor() {
        _transferOwnership(_msgSender());

        logic = address(new Divisible());
    }

    /**
     * @dev Adds a divisible proxy contract address to the whitelist.
     * Only the owner can perform this action.
     * @param proxyAddress The address of the divisible proxy contract to be added to the whitelist.
     * @return A boolean indicating whether the operation was successful.
     */
    function addToWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        divisibleWhitelist[proxyAddress] = true;

        return true;
    }

    /**
     * @dev Removes a divisible proxy contract address from the whitelist.
     * Only the owner can perform this action.
     * @param proxyAddress The address of the divisible proxy contract to be removed from the whitelist.
     * @return A boolean indicating whether the operation was successful.
     */
    function removeFromWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        divisibleWhitelist[proxyAddress] = false;

        return true;
    }

    /**
     * @dev Divides an ERC721 token into multiple divisible tokens.
     * Creates a new divisible proxy contract associated with the divided token.
     * Transfers the ownership of the ERC721 token to the divisible proxy contract.
     * Only the owner of the ERC721 token can perform this action.
     * @param originAddress The address of the original ERC721 token contract.
     * @param tokenId The ID of the ERC721 token to be divided.
     * @param totalSupply The total supply of the new divisible tokens.
     * @param name The name of the new divisible tokens.
     * @param symbol The symbol of the new divisible tokens.
     * @return The ID of the newly created divisible token.
     */
    function divide(
        address originAddress,
        uint256 tokenId,
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external override returns (uint256) {
        bytes memory _initializationCalldata = abi.encodeWithSignature(
            "initialize(address,address,uint256,uint256,string,string)",
            _msgSender(),
            originAddress,
            tokenId,
            totalSupply,
            name,
            symbol
        );

        address divisibleProxy = address(
            new InitializedProxy(logic, _initializationCalldata)
        );

        emit Divide(
            _msgSender(),
            originAddress,
            tokenId,
            divisibleProxy,
            divisibleCount
        );

        IERC721(originAddress).safeTransferFrom(
            _msgSender(),
            divisibleProxy,
            tokenId
        );

        divisibles[divisibleCount] = divisibleProxy;
        divisibleCount++;

        divisibleWhitelist[divisibleProxy] = true;

        return divisibleCount - 1;
    }
}
