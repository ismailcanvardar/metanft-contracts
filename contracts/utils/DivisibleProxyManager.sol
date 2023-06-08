// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./InitializedProxy.sol";
import "./Divisible.sol";
import "../interfaces/IDivisibleProxyManager.sol";

contract DivisibleProxyManager is Ownable, IDivisibleProxyManager {
  uint256 public divisibleCount;

  mapping(uint256 => address) private _divisibles;
  mapping(address => bool) private _divisibleWhitelist;

  address public immutable logic;

  event Divide(address indexed curator, address originAddress, uint256 tokenId, address divisible, uint256 divisibleId);

  constructor() {
    logic = address(new Divisible());
  }

  function getDivisible(uint256 divisibleId) public view returns(address) {
    return _divisibles[divisibleId];
  }

  function addToWhitelist(address proxyAddress) public onlyOwner returns(bool) {
    _divisibleWhitelist[proxyAddress] = true;

    return true;
  } 

  function removeFromWhitelist(address proxyAddress) public onlyOwner returns(bool) {
    _divisibleWhitelist[proxyAddress] = false;
    
    return true;
  }

  function divide(address originAddress, uint256 tokenId, uint256 totalSupply, string memory name, string memory symbol) override external returns(uint256) {
    bytes memory _initializationCalldata =
      abi.encodeWithSignature(
        "initialize(address,address,uint256,uint256,string,string)",
          msg.sender,
          originAddress,
          tokenId,
          totalSupply,
          name,
          symbol
    );

    address divisibleProxy = address(
      new InitializedProxy(
        logic,
        _initializationCalldata
      )
    );

    emit Divide(msg.sender, originAddress, tokenId, divisibleProxy, divisibleCount);

    IERC721(originAddress).safeTransferFrom(msg.sender, divisibleProxy, tokenId);
    
    // TODO: Kontratlara kapat

    _divisibles[divisibleCount] = divisibleProxy;
    divisibleCount++;

    _divisibleWhitelist[divisibleProxy] = true;

    return divisibleCount - 1;
  }
}