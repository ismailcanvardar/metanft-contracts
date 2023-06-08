// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../helpers/Payment.sol";
import "../interfaces/IRentableConfig.sol";

contract Rentable is Ownable2Step, Payment {
    address private _FEE_COLLECTOR;
    IRentableConfig private _RENTABLE_CONFIG;

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

    mapping(address => mapping(uint256 => bool)) internal _activeRents;
    mapping(address => mapping(uint256 => Lease)) internal _leases;
    mapping(address => mapping(uint256 => address)) internal _tennants;

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

        _FEE_COLLECTOR = _feeCollector;
        _RENTABLE_CONFIG = _rentableConfig;
    }

    modifier isRentable(address _originAddress, uint256 _tokenId) {
        require(
            !_activeRents[_originAddress][_tokenId],
            "isRentable: Item is already rented."
        );
        _;
    }

    modifier isAssetOwner(address _originAddress, uint256 _tokenId) {
        require(
            _leases[_originAddress][_tokenId].asset.owner == _msgSender(),
            "isAssetOwner: Only asset owner can do this action."
        );
        _;
    }

    function getFeeCollector() public view returns (address) {
        return _FEE_COLLECTOR;
    }

    function getRentableConfig() public view returns (IRentableConfig) {
        return _RENTABLE_CONFIG;
    }

    function getAssetInfo(
        address originAddress,
        uint256 tokenId
    ) public view returns (bool, Lease memory, address) {
        return (
            _activeRents[originAddress][tokenId],
            _leases[originAddress][tokenId],
            _tennants[originAddress][tokenId]
        );
    }

    function setFeeCollector(address newAddress) public onlyOwner {
        _FEE_COLLECTOR = newAddress;

        emit SetFeeCollector(newAddress);
    }

    function setRentableConfig(IRentableConfig newAddress) public onlyOwner {
        _RENTABLE_CONFIG = newAddress;

        emit SetRentableConfig(newAddress);
    }

    function putAssetOnRent(
        address originAddress,
        uint256 tokenId,
        bool hasCollateral,
        uint256 collateralAmount,
        uint256 pricePerDay
    ) public isRentable(originAddress, tokenId) returns (bool) {
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

        _leases[originAddress][tokenId] = Lease(
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
    ) public payable isRentable(originAddress, tokenId) returns (bool) {
        Lease storage leaseInstance = _leases[originAddress][tokenId];

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

        (uint256 fee, uint256 chargeAfterFee) = _RENTABLE_CONFIG
            .getAmountAfterFee(charge, false);

        require(chargeAfterFee <= msg.value, "lease: Insufficient funds.");

        leaseInstance.expirationDate =
            block.timestamp +
            (rentDurationInDays * (60 * 60 * 24));
        leaseInstance.charge = charge;
        leaseInstance.fee = fee;

        Payment.safeSendETH(_msgSender(), leaseInstance.asset.owner, charge);

        Payment.safeSendETH(_msgSender(), _FEE_COLLECTOR, fee);

        _activeRents[originAddress][tokenId] = true;
        _tennants[originAddress][tokenId] = _msgSender();

        emit CompleteLease(originAddress, tokenId, rentDurationInDays);

        return true;
    }

    function endLease(
        address originAddress,
        uint256 tokenId
    ) public payable isAssetOwner(originAddress, tokenId) returns (bool) {
        Lease storage leaseInstance = _leases[originAddress][tokenId];

        require(
            leaseInstance.expirationDate < block.timestamp,
            "endLease: You cannot end lease before expiration date."
        );

        uint256 refundAmount;

        if (leaseInstance.hasCollateral) {
            refundAmount = leaseInstance.collateralAmount;
        }

        (uint256 fee, ) = _RENTABLE_CONFIG.getAmountAfterFee(
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
                _tennants[originAddress][tokenId],
                leaseInstance.collateralAmount
            );
        }

        Payment.safeSendETH(_msgSender(), _FEE_COLLECTOR, fee);

        IERC721 contractInstance = IERC721(originAddress);
        contractInstance.transferFrom(
            address(this),
            leaseInstance.asset.owner,
            tokenId
        );

        delete _leases[originAddress][tokenId];
        delete _tennants[originAddress][tokenId];

        _activeRents[originAddress][tokenId] = false;

        return true;
    }
}
