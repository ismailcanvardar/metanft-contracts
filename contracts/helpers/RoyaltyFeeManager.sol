// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../lib/RoyaltyFeeManagerStructs.sol";

/**
 * @title RoyaltyFeeManager
 * @dev A contract for managing royalty fee configurations for NFTs.
 */
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

    /**
     * @dev Constructor.
     * @param _maximumPercentage The maximum fee percentage allowed.
     */
    constructor(uint8 _maximumPercentage) {
        maximumFeePercentage = _maximumPercentage;
    }

    /**
     * @dev Modifier to check if the caller is the owner of the NFT.
     */
    modifier onlyAssetOwner(address _originAddress, uint256 _tokenId) {
        IERC721 erc721Instance = IERC721(_originAddress);
        require(erc721Instance.ownerOf(_tokenId) == msg.sender);
        _;
    }

    /**
     * @dev Modifier to check if the caller is the creator of the NFT.
     */
    modifier onlyCreator(address _originAddress, uint256 _tokenId) {
        require(creators[_originAddress][_tokenId] == msg.sender);
        _;
    }

    /**
     * @dev Retrieves the royalty fee configuration for the given NFT.
     * @param originAddress The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @return The royalty fee configuration for the NFT.
     */
    function getRoyaltyFeeConfig(
        address originAddress,
        uint256 tokenId
    ) external view returns (RoyaltyFeeManagerStructs.RoyaltyFeeConfig memory) {
        return configs[originAddress][tokenId];
    }

    /**
     * @dev Sets the creator of the NFT.
     * @param originAddress The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @return A boolean indicating whether the creator was set successfully.
     */
    function setCreator(
        address originAddress,
        uint256 tokenId
    ) external onlyAssetOwner(originAddress, tokenId) returns (bool) {
        creators[originAddress][tokenId] = msg.sender;

        emit SetCreator(originAddress, tokenId);

        return true;
    }

    /**
     * @dev Registers a royalty fee configuration for the NFT.
     * @param originAddress The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @param newCreator The address of the new creator.
     * @param newFeePercentage The new fee percentage for royalties.
     * @param isOwnershipTransferable A boolean indicating whether the ownership of the NFT is transferable.
     * @return A boolean indicating whether the royalty fee configuration was registered successfully.
     */
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

    /**
     * @dev Checks if the NFT has a royalty fee configured.
     * @param originAddress The address of the NFT contract.
     * @param tokenId The ID of the NFT.
     * @return A boolean indicating whether the NFT has a royalty fee configured.
     */
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

    /**
     * @dev Calculates the royalty fee amount based on the given amount and fee percentage.
     * @param amount The original amount.
     * @param feePercentage The fee percentage for royalties.
     * @return The royalty fee amount.
     */
    function calculateRoyaltyFee(
        uint256 amount,
        uint256 feePercentage
    ) public pure returns (uint256) {
        return (amount * feePercentage) / BASE_DIVIDER;
    }
}
