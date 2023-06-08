// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "./Divisible.sol";
import "../interfaces/IDivisibleProxyManager.sol";

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

    function addToWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        divisibleWhitelist[proxyAddress] = true;

        return true;
    }

    function removeFromWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        divisibleWhitelist[proxyAddress] = false;

        return true;
    }

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
