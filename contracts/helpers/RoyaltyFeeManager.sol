// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../lib/RoyaltyFeeManagerStructs.sol";

contract RoyaltyFeeManager {
    uint8 public constant BASE_DIVIDER = 100;
    uint8 public maximumFeePercentage;
    mapping(address => mapping(uint256 => RoyaltyFeeManagerStructs.RoyaltyFeeConfig))
        private configs;
    mapping(address => mapping(uint256 => address)) private creators;

    event SetCreator(address originAddress, uint256 tokenId);
    event RegisterRoyaltyFeeConfig(
        address originAddress,
        uint256 tokenId,
        address newCreator
    );

    constructor(uint8 _maximumPercentage) {
        maximumFeePercentage = _maximumPercentage;
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

    function getRoyaltyFeeConfig(
        address originAddress,
        uint256 tokenId
    ) external view returns (RoyaltyFeeManagerStructs.RoyaltyFeeConfig memory) {
        return configs[originAddress][tokenId];
    }

    function setCreator(
        address originAddress,
        uint256 tokenId
    ) external onlyAssetOwner(originAddress, tokenId) returns (bool) {
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
    ) external onlyCreator(originAddress, tokenId) returns (bool) {
        require(
            newFeePercentage <= maximumFeePercentage,
            "registerRoyaltyFeeConfig: Fee percentage must be lower than or equal to maximum percentage."
        );
        RoyaltyFeeManagerStructs.RoyaltyFeeConfig storage config = configs[
            originAddress
        ][tokenId];

        if (config.creator == address(0)) {
            config.creator = newCreator;
            config.feePercentage = newFeePercentage;
            config.isOwnershipTransferable = isOwnershipTransferable;

            emit RegisterRoyaltyFeeConfig(originAddress, tokenId, newCreator);

            return true;
        }

        return false;
    }

    function hasRoyaltyFee(
        address originAddress,
        uint256 tokenId
    ) public view returns (bool) {
        RoyaltyFeeManagerStructs.RoyaltyFeeConfig
            memory royaltyFeeConfig = configs[originAddress][tokenId];

        uint feePercentage = royaltyFeeConfig.feePercentage;

        if (feePercentage == 0) {
            return false;
        }

        return true;
    }

    function calculateRoyaltyFee(
        uint256 amount,
        uint256 feePercentage
    ) public pure returns (uint256) {
        return (amount * feePercentage) / BASE_DIVIDER;
    }
}
