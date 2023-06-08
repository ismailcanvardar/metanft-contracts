// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

contract Fractional is ERC721URIStorageUpgradeable, ERC721HolderUpgradeable {
    using Counters for Counters.Counter;
    Counters.Counter private _fractionIds;
    address public originAddress;
    uint256 public tokenId;
    address public curator;
    uint256 LENGTH_LIMIT = 100;

    event Reclaim(address newOwner, address originAddress, uint256 tokenId);

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
