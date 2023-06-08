// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

contract Fractional is ERC721URIStorageUpgradeable, ERC721HolderUpgradeable {
    using Counters for Counters.Counter;
    Counters.Counter private _fractionIds;
    address private _ORIGIN_ADDRESS;
    uint256 private _TOKEN_ID;
    address private _CURATOR;
    uint256 LENGTH_LIMIT = 100;

    event Reclaim(address newOwner, address originAddress, uint256 tokenId);

    function initialize(
        address curator,
        address originAddress,
        uint256 tokenId,
        string[] memory tokenURIs,
        string memory name,
        string memory symbol
    ) external initializer {
        __ERC721_init(name, symbol);
        __ERC721Holder_init();
        _ORIGIN_ADDRESS = originAddress;
        _TOKEN_ID = tokenId;
        _CURATOR = curator;

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

    function reclaim() external {
        require(
            balanceOf(_msgSender()) == _fractionIds.current(),
            "reclaim: Must own total supply of tokens."
        );

        IERC721(_ORIGIN_ADDRESS).transferFrom(
            address(this),
            _msgSender(),
            _TOKEN_ID
        );

        emit Reclaim(_msgSender(), _ORIGIN_ADDRESS, _TOKEN_ID);
    }
}
