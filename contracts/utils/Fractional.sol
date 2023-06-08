// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

/**
 * @title Fractional
 * @dev A contract for creating fractionalized ERC721 tokens.
 * The contract allows the curator to divide an ERC721 token into multiple fractional tokens with unique tokenURIs.
 * It implements the ERC721URIStorageUpgradeable and ERC721HolderUpgradeable contracts.
 */
contract Fractional is ERC721URIStorageUpgradeable, ERC721HolderUpgradeable {
    using Counters for Counters.Counter;
    Counters.Counter private _fractionIds;
    address public originAddress;
    uint256 public tokenId;
    address public curator;
    uint256 LENGTH_LIMIT = 100;

    event Reclaim(address newOwner, address originAddress, uint256 tokenId);

    /**
     * @dev Initializes the Fractional contract.
     * @param _curator The address of the curator who owns the original ERC721 token.
     * @param _originAddress The address of the original ERC721 contract.
     * @param _tokenId The ID of the original ERC721 token.
     * @param tokenURIs An array of tokenURIs for the fractional tokens.
     * @param name The name of the fractional token.
     * @param symbol The symbol of the fractional token.
     */
    function initialize(
        address _curator,
        address _originAddress,
        uint256 _tokenId,
        string[] memory tokenURIs,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC721_init(name, symbol);
        __ERC721Holder_init();
        originAddress = _originAddress;
        tokenId = _tokenId;
        curator = _curator;

        uint256 tokenLength = tokenURIs.length;

        require(
            tokenLength < LENGTH_LIMIT,
            "initialize: Maximum length exceeded!"
        );

        for (uint256 i = 0; i < tokenLength; ) {
            uint256 newFractionId = _fractionIds.current();
            _mint(curator, newFractionId);
            _setTokenURI(newFractionId, tokenURIs[i]);
            _fractionIds.increment();

            unchecked {
                i += 1;
            }
        }
    }

    /**
     * @dev Allows the curator to reclaim the original ERC721 token after fractionalization is complete.
     */
    function reclaim() external {
        require(
            balanceOf(_msgSender()) == _fractionIds.current(),
            "reclaim: Must own total supply of tokens."
        );

        IERC721(originAddress).transferFrom(
            address(this),
            _msgSender(),
            tokenId
        );

        emit Reclaim(_msgSender(), originAddress, tokenId);
    }
}
