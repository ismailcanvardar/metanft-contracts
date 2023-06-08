// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "./Fractional.sol";
import "../interfaces/IFractionalProxyManager.sol";

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

    function addToWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        fractionalWhitelist[proxyAddress] = true;

        return true;
    }

    function removeFromWhitelist(
        address proxyAddress
    ) external onlyOwner returns (bool) {
        fractionalWhitelist[proxyAddress] = false;

        return true;
    }

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
