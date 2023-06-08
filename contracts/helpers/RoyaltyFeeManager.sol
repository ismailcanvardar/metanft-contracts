// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../lib/RoyaltyFeeManagerStructs.sol";

contract RoyaltyFeeManager {
    uint8 private constant _BASE_DIVIDER = 100;
    uint8 private _MAXIMUM_FEE_PERCENTAGE;
    mapping(address => mapping(uint256 => RoyaltyFeeManagerStructs.RoyaltyFeeConfig)) private configs;
    mapping(address => mapping(uint256 => address)) private creators;

    event SetCreator(address originAddress, uint256 tokenId);
    event RegisterRoyaltyFeeConfig(address originAddress, uint256 tokenId, address newCreator);

    constructor(uint8 _maximumPercentage) {
        _MAXIMUM_FEE_PERCENTAGE = _maximumPercentage;
    }

    modifier onlyAssetOwner(address _originAddress, uint256 _tokenId) {
        IERC721 erc721Instance = IERC721(_originAddress);
        require(erc721Instance.ownerOf(_tokenId) == msg.sender);
        _;
    }

    modifier onlyCreator(address _originAddress, uint256 _tokenId) {
        require(creators[_originAddress][_tokenId] == msg.sender);
        _;
    }

    function getCreator(address originAddress, uint256 tokenId) external view returns(address) {
        return creators[originAddress][tokenId];
    }

    function hasRoyaltyFee(address originAddress, uint256 tokenId) public view returns(bool) {
        RoyaltyFeeManagerStructs.RoyaltyFeeConfig memory royaltyFeeConfig = configs[originAddress][tokenId];

        uint feePercentage = royaltyFeeConfig.feePercentage;

        if (feePercentage == 0) {
            return false;
        }

        return true;
    }

    function getRoyaltyFeeConfig(address originAddress, uint256 tokenId) external view returns(RoyaltyFeeManagerStructs.RoyaltyFeeConfig memory) {
        return configs[originAddress][tokenId];
    }

    function setCreator(address originAddress, uint256 tokenId) onlyAssetOwner(originAddress, tokenId) external returns(bool) {
        creators[originAddress][tokenId] = msg.sender;

        emit SetCreator(originAddress, tokenId);

        return true;
    }

    function registerRoyaltyFeeConfig(
        address originAddress, 
        uint256 tokenId,
        address newCreator, 
        uint256 newFeePercentage, 
        bool isOwnershipTransferable
    ) onlyCreator(originAddress, tokenId) external returns(bool) {
        require(newFeePercentage <= _MAXIMUM_FEE_PERCENTAGE, "registerRoyaltyFeeConfig: Fee percentage must be lower than or equal to maximum percentage.");
        RoyaltyFeeManagerStructs.RoyaltyFeeConfig storage config = configs[originAddress][tokenId];

        if (config.creator == address(0)) {
            config.creator = newCreator;
            config.feePercentage = newFeePercentage;
            config.isOwnershipTransferable = isOwnershipTransferable;

            emit RegisterRoyaltyFeeConfig(originAddress, tokenId, newCreator);

            return true;
        }

        return false;
    }

    function calculateRoyaltyFee(uint256 amount, uint256 feePercentage) external pure returns(uint256) {
        return (amount * feePercentage) / _BASE_DIVIDER;
    }
}