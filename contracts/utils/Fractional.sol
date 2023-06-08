// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

contract Fractional is ERC721URIStorageUpgradeable, ERC721HolderUpgradeable {
    using Counters for Counters.Counter;
    Counters.Counter private _fractionIds;
    // kontrata kitlenen NFT'nin adresi
    address private _ORIGIN_ADDRESS;
    // kontrata kitlenen NFT'nin id si
    uint256 private _TOKEN_ID;
    // NFT'sini parçalayan, NFT oluşturucu adresi
    address private _CURATOR;
    // Maksimum basılacak NFT limiti
    uint256 LENGTH_LIMIT = 100;

    event Reclaim(address newOwner, address originAddress, uint256 tokenId);

    // Hisseli NFT için token üreten ve token'ın bilgilerini sağlayan başlatıcı fonksiyon 
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

        // TODO: Token limitini kontrol et
        require(tokenLength < LENGTH_LIMIT, "initialize: Maximum length exceeded!");

        // Kontrat oluşutucu adresin istediği miktarda token üret
        for (uint256 i = 0; i < tokenLength;) {
            uint256 newFractionId = _fractionIds.current();
            _mint(curator, newFractionId);
            _setTokenURI(newFractionId, tokenURIs[i]);
            _fractionIds.increment();

            unchecked {
                i+=1;
            }
        }
    }

    // Kontrata kilitli NFT'yi geri almak için kullanılan fonksiyon (sadece bütünlüğü sağlanan parça sayısı sağlanırsa gerçekleşebilecek fonksiyon)
    function reclaim() external {
        require(balanceOf(msg.sender) == _fractionIds.current(), "reclaim: Must own total supply of tokens.");

        // Kilitli token'i tüm hisselere sahip kişiye yollamak kullanılan metot
        IERC721(_ORIGIN_ADDRESS).transferFrom(address(this), msg.sender, _TOKEN_ID);

        emit Reclaim(msg.sender, _ORIGIN_ADDRESS, _TOKEN_ID);
    }
}