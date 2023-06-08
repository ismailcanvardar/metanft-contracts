// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import "../helpers/Payment.sol";
import "../interfaces/IRentableConfig.sol";

contract Rentable is Ownable, Payment {
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

    event PutAssetOnRent(address originAddress, uint256 tokenId, address seller);
    event CompleteLease(address originAddress, uint256 tokenId, uint256 rentDurationInDays);
    event SetFeeCollector(address newAddress);
    event SetRentableConfig(IRentableConfig newAddress);

    constructor(address _feeCollector, IRentableConfig _rentableConfig) {
        _FEE_COLLECTOR = _feeCollector;
        _RENTABLE_CONFIG = _rentableConfig;
    }

    modifier isRentable(address _originAddress, uint256 _tokenId) {
        require(!_activeRents[_originAddress][_tokenId], "isRentable: Item is already rented.");
        _;
    }

    modifier isAssetOwner(address _originAddress, uint256 _tokenId) {
        require(_leases[_originAddress][_tokenId].asset.owner == msg.sender, "isAssetOwner: Only asset owner can do this action.");
        _;
    }

    function getFeeCollector() public view returns(address) {
        return _FEE_COLLECTOR;
    }

    function getRentableConfig() public view returns(IRentableConfig) {
        return _RENTABLE_CONFIG;
    }

    function getAssetInfo(address originAddress, uint256 tokenId) public view returns(bool, Lease memory, address) {
        // isActive
        // leaseInfo
        // currentTennant
        return (
            _activeRents[originAddress][tokenId],
            _leases[originAddress][tokenId],
            _tennants[originAddress][tokenId]
        );
    }

    // FeeCollector adresini değiştirir 
    function setFeeCollector(address newAddress) public onlyOwner {
        _FEE_COLLECTOR = newAddress;
        
        emit SetFeeCollector(newAddress);
    }

    // RentableConfig adresini değiştirir 
    function setRentableConfig(IRentableConfig newAddress) public onlyOwner {
        _RENTABLE_CONFIG = newAddress;

        emit SetRentableConfig(newAddress);
    }

    // Ürün sahibinin markete ilan koymasını sağlar,
    // Kullanıcının ürünü markete deposit etmesi gereklidir
    // Deposit sonrası kira kontratı oluşturur, böylelikle ürün kiralabilir hale gelir
    function putAssetOnRent(
        address originAddress, 
        uint256 tokenId, 
        bool hasCollateral, 
        uint256 collateralAmount, 
        uint256 pricePerDay
    )
        isRentable(originAddress, tokenId) 
        public returns(bool) 
    {
        IERC721 contractInstance = IERC721(originAddress);

        // Kontrat ürünün sahibi mi kontrol eder, eğer değilse approval kontrol eder
        if (contractInstance.ownerOf(tokenId) != address(this)) {
            // Ürün gerçekten yollayana mı ait kontrol eder
            require(contractInstance.ownerOf(tokenId) == msg.sender, "putAssetOnRent: Must be owner of asset.");
            // Ürünü approval kontrolü yapılır
            require(contractInstance.getApproved(tokenId) == address(this), "putAssetOnRent: Asset owner must approve token.");

            // Eğer ürün approval edildiyse, kontrata transferi gerçekleşir
            contractInstance.transferFrom(msg.sender, address(this), tokenId);
        }

        // Daha sonrasında kiralabilmesi için bir kira kontratı oluşturulur
        _leases[originAddress][tokenId] = Lease(Asset(originAddress, tokenId, msg.sender), hasCollateral, collateralAmount, pricePerDay, 0, 0, 0);

        emit PutAssetOnRent(originAddress, tokenId, msg.sender);

        return true;
    }

    // Marketten seçilen kira kontratını imzalamak için kullanılır
    function lease(
        address originAddress, 
        uint256 tokenId, 
        uint256 rentDurationInDays
    )
        isRentable(originAddress, tokenId) 
        public payable returns(bool) 
    {
        Lease storage leaseInstance = _leases[originAddress][tokenId];

        // Ürün sahini kendi ürününü kiralayamaz
        require(leaseInstance.asset.owner != msg.sender, "lease: Cannot rent your asset.");

        // Ödenecek tutarı belirtir
        uint256 charge;

        // Eğer ürün teminatlı ise ödenecek tutara teminat da eklenir
        if (leaseInstance.hasCollateral) {
            // Günlük fiyat ile kiralanacak gün çarpılıp toplamda ödenecek tutar belirlenir, teminatlı ise üstüne teminat değeri de eklenir
            charge = (leaseInstance.pricePerDay * rentDurationInDays) + leaseInstance.collateralAmount;
        } else {
            charge = leaseInstance.pricePerDay * rentDurationInDays;
        }

        // Ödenecek tutar üzerinden kiracı komisyonu hesaplanır
        (uint256 fee, uint256 chargeAfterFee) = _RENTABLE_CONFIG.getAmountAfterFee(charge, false);

        // Kiracı tarafından yollanan değer, toplam ödenecek tutar ve komisyon toplamından büyük veya eşit olmalıdır
        require(chargeAfterFee <= msg.value, "lease: Insufficient funds.");

        // Kira kontratı güncellenir, kiralamanın bitiş tarihi, toplam ödenen tutar ve komisyon eklenir
        leaseInstance.expirationDate = block.timestamp + (rentDurationInDays * (60 * 60 * 24));
        leaseInstance.charge = charge;
        leaseInstance.fee = fee;

        // Ürün sahibine kiracı tarafından ödenen tutar gönderilir
        Payment.safeSendETH(msg.sender, leaseInstance.asset.owner, charge);

        // Fee Collector adresine komisyon gönderilir
        Payment.safeSendETH(msg.sender, _FEE_COLLECTOR, fee);

        // Ürünün statüsü kirada olarak güncellenir
        _activeRents[originAddress][tokenId] = true;
        _tennants[originAddress][tokenId] = msg.sender;

        emit CompleteLease(originAddress, tokenId, rentDurationInDays);

        return true;
    }

    // Ürün sahibinin kiralama bittikten sonra kullandığı metot
    function endLease(
        address originAddress, 
        uint256 tokenId
    ) 
        isAssetOwner(originAddress, tokenId)
        public payable returns(bool) 
    {
        Lease storage leaseInstance = _leases[originAddress][tokenId];

        // Kiralama süresi içerisinde kira kontratı bitirilemez
        require(leaseInstance.expirationDate < block.timestamp, "endLease: You cannot end lease before expiration date.");

        uint256 refundAmount;

        if (leaseInstance.hasCollateral) {
            refundAmount = leaseInstance.collateralAmount;
        }

        (uint256 fee, ) = _RENTABLE_CONFIG.getAmountAfterFee(leaseInstance.charge, true);

        refundAmount += fee;

        require(refundAmount <= msg.value, "endLease: Needs to deposit collateral for this action.");

        if (leaseInstance.hasCollateral) {
            Payment.safeSendETH(msg.sender, _tennants[originAddress][tokenId], leaseInstance.collateralAmount);
        }

        Payment.safeSendETH(msg.sender, _FEE_COLLECTOR, fee);

        IERC721 contractInstance = IERC721(originAddress);
        contractInstance.transferFrom(address(this), leaseInstance.asset.owner, tokenId);

        delete _leases[originAddress][tokenId];
        delete _tennants[originAddress][tokenId];
        
        _activeRents[originAddress][tokenId] = false;

        return true;
    }
}