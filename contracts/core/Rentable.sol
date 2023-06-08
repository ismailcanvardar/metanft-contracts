// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../helpers/Payment.sol";
import "../interfaces/IRentableConfig.sol";

contract Rentable is Ownable2Step, Payment {
    address public feeCollector;
    IRentableConfig public rentableConfig;
    mapping(address => mapping(uint256 => bool)) public activeRents;
    mapping(address => mapping(uint256 => Lease)) public leases;
    mapping(address => mapping(uint256 => address)) public tennants;

    struct Asset {
        address originAddress;
        uint256 tokenId;
        address owner;
    }

    struct Lease {
        Asset asset;
        bool hasCollateral;
        uint256 collateralAmount;
        uint256 pricePerDay;
        uint256 expirationDate;
        uint256 charge;
        uint256 fee;
    }

    event PutAssetOnRent(
        address originAddress,
        uint256 tokenId,
        address seller
    );
    event CompleteLease(
        address originAddress,
        uint256 tokenId,
        uint256 rentDurationInDays
    );
    event SetFeeCollector(address newAddress);
    event SetRentableConfig(IRentableConfig newAddress);

    constructor(address _feeCollector, IRentableConfig _rentableConfig) {
        _transferOwnership(_msgSender());

        feeCollector = _feeCollector;
        rentableConfig = _rentableConfig;
    }

    modifier isRentable(address _originAddress, uint256 _tokenId) {
        require(
            !activeRents[_originAddress][_tokenId],
            "isRentable: Item is already rented."
        );
        _;
    }

    modifier isAssetOwner(address _originAddress, uint256 _tokenId) {
        require(
            leases[_originAddress][_tokenId].asset.owner == _msgSender(),
            "isAssetOwner: Only asset owner can do this action."
        );
        _;
    }

    function setFeeCollector(address newAddress) external onlyOwner {
        feeCollector = newAddress;

        emit SetFeeCollector(newAddress);
    }

    function setRentableConfig(IRentableConfig newAddress) external onlyOwner {
        rentableConfig = newAddress;

        emit SetRentableConfig(newAddress);
    }

    function putAssetOnRent(
        address originAddress,
        uint256 tokenId,
        bool hasCollateral,
        uint256 collateralAmount,
        uint256 pricePerDay
    ) external isRentable(originAddress, tokenId) returns (bool) {
        IERC721 contractInstance = IERC721(originAddress);

        if (contractInstance.ownerOf(tokenId) != address(this)) {
            require(
                contractInstance.ownerOf(tokenId) == _msgSender(),
                "putAssetOnRent: Must be owner of asset."
            );
            require(
                contractInstance.getApproved(tokenId) == address(this),
                "putAssetOnRent: Asset owner must approve token."
            );

            contractInstance.transferFrom(_msgSender(), address(this), tokenId);
        }

        leases[originAddress][tokenId] = Lease(
            Asset(originAddress, tokenId, _msgSender()),
            hasCollateral,
            collateralAmount,
            pricePerDay,
            0,
            0,
            0
        );

        emit PutAssetOnRent(originAddress, tokenId, _msgSender());

        return true;
    }

    function lease(
        address originAddress,
        uint256 tokenId,
        uint256 rentDurationInDays
    ) external payable isRentable(originAddress, tokenId) returns (bool) {
        Lease storage leaseInstance = leases[originAddress][tokenId];

        require(
            leaseInstance.asset.owner != _msgSender(),
            "lease: Cannot rent your asset."
        );

        uint256 charge = 0;

        if (leaseInstance.hasCollateral) {
            charge =
                (leaseInstance.pricePerDay * rentDurationInDays) +
                leaseInstance.collateralAmount;
        } else {
            charge = leaseInstance.pricePerDay * rentDurationInDays;
        }

        (uint256 fee, uint256 chargeAfterFee) = rentableConfig
            .getAmountAfterFee(charge, false);

        require(chargeAfterFee <= msg.value, "lease: Insufficient funds.");

        leaseInstance.expirationDate =
            block.timestamp +
            (rentDurationInDays * (60 * 60 * 24));
        leaseInstance.charge = charge;
        leaseInstance.fee = fee;

        Payment.safeSendETH(_msgSender(), leaseInstance.asset.owner, charge);

        Payment.safeSendETH(_msgSender(), feeCollector, fee);

        activeRents[originAddress][tokenId] = true;
        tennants[originAddress][tokenId] = _msgSender();

        emit CompleteLease(originAddress, tokenId, rentDurationInDays);

        return true;
    }

    function endLease(
        address originAddress,
        uint256 tokenId
    ) external payable isAssetOwner(originAddress, tokenId) returns (bool) {
        Lease storage leaseInstance = leases[originAddress][tokenId];

        require(
            leaseInstance.expirationDate < block.timestamp,
            "endLease: You cannot end lease before expiration date."
        );

        uint256 refundAmount;

        if (leaseInstance.hasCollateral) {
            refundAmount = leaseInstance.collateralAmount;
        }

        (uint256 fee, ) = rentableConfig.getAmountAfterFee(
            leaseInstance.charge,
            true
        );

        refundAmount += fee;

        require(
            refundAmount <= msg.value,
            "endLease: Needs to deposit collateral for this action."
        );

        if (leaseInstance.hasCollateral) {
            Payment.safeSendETH(
                _msgSender(),
                tennants[originAddress][tokenId],
                leaseInstance.collateralAmount
            );
        }

        Payment.safeSendETH(_msgSender(), feeCollector, fee);

        IERC721 contractInstance = IERC721(originAddress);
        contractInstance.transferFrom(
            address(this),
            leaseInstance.asset.owner,
            tokenId
        );

        delete leases[originAddress][tokenId];
        delete tennants[originAddress][tokenId];

        activeRents[originAddress][tokenId] = false;

        return true;
    }

    function getAssetInfo(
        address originAddress,
        uint256 tokenId
    ) public view returns (bool, Lease memory, address) {
        return (
            activeRents[originAddress][tokenId],
            leases[originAddress][tokenId],
            tennants[originAddress][tokenId]
        );
    }
}
