// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";

contract Divisible is ERC20Upgradeable, ERC721HolderUpgradeable {
    // kontrata kitlenen NFT'nin adresi
    address private _ORIGIN_ADDRESS;
    // kontrata kitlenen NFT'nin id si
    uint256 private _TOKEN_ID;
    // NFT'sini parçalayan, NFT oluşturucu adresi
    address private _CURATOR;
    // güncel fiyat değeri, bu fiyat ileride alış satışlarda referans görevindedir
    uint256 public currentPrice;
    // Listeleme için minimum veya maksimum fiyatı güncel fiyatla hesaplamak için kullanılır
    uint256 public priceRulePercentage = 5;
    // Listelemede kullanıcı başına fiyat listesi
    mapping(address => uint256) public listPrices;
    // Listelemede kullanıcı başına satılan miktar
    mapping(address => uint256) public listAmount;

    // ether tipinde satış fiyatı
    uint256 public salePrice;
    // satışın timestamp tipinde uzunluğu
    uint256 public saleLength;
    // satışın başlangıç block.timestamp değeri
    uint256 public startBlock;
    // satışın statüsü (aktif veya inaktif halde)
    SaleStatus public saleStatus;
    // satışta satılacak token miktarı
    uint256 public saleAmount;
    // satılan token miktarı
    uint256 public soldAmount = 0;

    enum SaleStatus {
        INACTIVE,
        ACTIVE,
        DONE
    }

    event Reclaim(address newOwner, address originAddress, uint256 tokenId);
    //event SetSalePrice(uint256 newPrice);
    event BuyDivisibleFromSale(address indexed account, uint256 amount);
    event CashOut(address indexed account, uint256 amount);
    event StartSale(
        address indexed curator,
        uint256 salePrice,
        uint256 saleLength
    );
    event List(address indexed account, uint256 amount, uint256 price);
    event DirectBuy(
        address indexed buyer,
        address indexed from,
        uint256 amount,
        uint256 price
    );
    event EndSale(SaleStatus saleStatus);
    event CancelListing(address indexed account, uint256 amount, uint256 price);

    // Sadece NFT sahibinin çağırabileceği modifier
    modifier onlyCurator() {
        require(msg.sender == _CURATOR, "onlyCurator: Lack of permission.");
        _;
    }

    // Hisseli NFT için token üreten ve token'ın bilgilerini sağlayan başlatıcı fonksiyon
    function initialize(
        address curator,
        address originAddress,
        uint256 tokenId,
        uint256 totalSupply,
        string memory name,
        string memory symbol
    ) external initializer {
        // kalıtım yapılan kontratları başlat
        __ERC20_init(name, symbol);
        __ERC721Holder_init();
        _ORIGIN_ADDRESS = originAddress;
        _TOKEN_ID = tokenId;
        _CURATOR = curator;

        _mint(curator, totalSupply);
    }

    // Satis bilgisini dondurur
    function getSaleInfo() public view returns (SaleStatus, uint256[5] memory) {
        return (
            saleStatus,
            [salePrice, saleLength, startBlock, saleAmount, soldAmount]
        );
    }

    // Min maks listeleme fiyatı kuralını değiştiren fonksiyon, sadece curator bu fonksiyonu çağırabilir
    function setPriceRulePercentage(
        uint256 newPriceRulePercentage
    ) public onlyCurator {
        priceRulePercentage = newPriceRulePercentage;
    }

    // Kontrata kitli ürünün bilgilerini al
    function getItemInfo() public view returns (address, uint256, address) {
        return (_ORIGIN_ADDRESS, _TOKEN_ID, _CURATOR);
    }

    // Ön satışı başlatan fonksiyon (bu fonksiyonu sadece NFT'sini hisselendiren yani curator çağırabilir)
    // Satış bilgilerini günceller, bunlar saleStatus: satışın durumu, saleLength: verilen block zamanından ne kadar zaman sonra biteceği
    // startBlock: fonksiyon çağırıldığındaki başlangıç zamanı, salePrice: satış fiyatı,
    // currentPrice: aktif satış fiyat (bunun kullanılma sebebi ileride hissedar satışlarında aktif fiyatı güncellemek için)
    function startSale(
        uint256 price,
        uint256 length,
        uint256 amount
    ) public onlyCurator {
        require(
            saleStatus == SaleStatus.INACTIVE,
            "startSale: Sale was started, already."
        );
        require(
            allowance(_CURATOR, address(this)) >= amount,
            "startSale: Has to approve tokens first!"
        );

        saleStatus = SaleStatus.ACTIVE;
        saleLength = length;
        startBlock = block.timestamp;
        salePrice = price;
        currentPrice = price;
        saleAmount = amount;

        emit StartSale(msg.sender, price, length);
    }

    // Hissedar olmak için kullanılan fonksiyon, amacı önsatıştaki hisseden yolladığı miktar kadar satın almak
    // Bu fonksiyonu kullanabilmek için ön satışın aktif olması gerekmektedir
    function buyDivisibleFromSale(uint256 amount) public payable {
        require(
            saleStatus == SaleStatus.ACTIVE,
            "buyDivisibleFromSale: Sale is not active."
        );
        require(
            block.timestamp < startBlock + saleLength,
            "buyDivisibleFromSale: Sale is ended."
        );
        require(
            soldAmount <= saleAmount && soldAmount + amount <= saleAmount,
            "buyDivisibleFromSale: Out of sale amount!"
        );

        uint256 cost = salePrice * (amount / 10 ** 18);
        require(msg.value >= cost, "buyDivisibleFromSale: Not enough funds.");

        // TODO: transferFrom'dan dönen data'ya bak
        // transferFrom(_CURATOR, msg.sender, amount) a karşılık gelir ancak burada yapılan
        // proxy call'un amacı bu işlemin kontrat tarafından yapılmasını sağlamak,
        // çünkü CURATOR satışı başlatmadan önce satmak istediği miktarı kontrata approve ediyor
        // böylece buyDivisibleFromSale fonksiyonunu çağıran kişi tetiklemesi yerine Divisible kontratı tetikliyor
        (bool sent, ) = address(this).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _CURATOR,
                msg.sender,
                amount
            )
        );
        require(sent, "buyDivisibleFromSale: Unable to transfer tokens.");

        soldAmount += amount;

        emit BuyDivisibleFromSale(msg.sender, amount);
    }

    // Önsatışı bitirmek için çağırılan fonksiyon.
    // Sadece curator bu fonksiyonu çağırabilir.
    // Bu fonksiyonu çağırmak için önsatışın belirtilen süreyi tamamlaması gerekmektedir.
    function endSale() public onlyCurator {
        require(
            saleStatus == SaleStatus.ACTIVE,
            "endSale: Sale is not active."
        );
        require(
            block.timestamp > startBlock + saleLength,
            "endSale: Sale has to be finished to make this action."
        );

        saleStatus = SaleStatus.DONE;

        emit EndSale(SaleStatus.DONE);
    }

    // Hissedarın elindeki tüm hisseleri, hisse ilk satış fiyatından elinde çıkarması
    // Bu fonksiyon sadece ön satış fiyatından hissedarın elindeki miktarı yakmaktadır
    function cashOut() public {
        require(
            saleStatus == SaleStatus.DONE,
            "cashOut: Cannot make this action before sale is ended."
        );

        uint256 balanceOfCaller = balanceOf(msg.sender);
        uint256 calculatedAmount = balanceOfCaller * salePrice;

        require(
            address(this).balance >= balanceOfCaller,
            "cashOut: Not enough balance in contract."
        );

        _burn(msg.sender, balanceOfCaller);
        // Kilitli token'i tüm hisselere sahip kişiye yollamak kullanılan metot
        (bool sent, ) = msg.sender.call{value: calculatedAmount}("");
        require(sent, "cashOut: Unable to send.");

        emit CashOut(msg.sender, balanceOfCaller);
    }

    // Hisse listeleme fonksiyonu,
    // Ön satış bitmedikçe bir kullanıcı hissesini satışa çıkaramaz
    // Listelemek için kullanıcı listelemek istediği miktar kadar platforma approve etmelidir
    // Listeleme yapması için bir kullanıcının, daha önceden bir listelemesi bulunmamalıdır
    function list(uint256 amount, uint256 price) public {
        // Ön satış bitti mi kontrol et
        require(
            saleStatus == SaleStatus.DONE,
            "list: Sale has to be finished in order to list tokens."
        );
        // Listeleyen kişi platforma approve vermiş mi kontrol et
        require(
            allowance(msg.sender, address(this)) >= amount,
            "list: Has to approve tokens first!"
        );
        // Daha önceden listelenmiş mi kontrol et
        require(
            listPrices[msg.sender] == 0 && listAmount[msg.sender] == 0,
            "list: Already listed before."
        );

        // minimum veya maksimum fiyatı belirt (mevcut fiyattan yüzde 5 az veya çok listeleme fiyatı belirtememeli)
        (uint256 min, uint256 max) = _calculatePriceRule();

        require(price <= max && price >= min, "list: Must ensure price rule.");

        listPrices[msg.sender] = price;
        listAmount[msg.sender] = amount;

        emit List(msg.sender, amount, price);
    }

    function cancelListing() public {
        require(
            listPrices[msg.sender] > 0 && listAmount[msg.sender] > 0,
            "cancelListing: Listing needed to make this action."
        );

        listPrices[msg.sender] = 0;
        listAmount[msg.sender] = 0;

        emit CancelListing(
            msg.sender,
            listPrices[msg.sender],
            listAmount[msg.sender]
        );
    }

    // Direkt satın alma fonksiyonu, ön satışın haricinde bu fonksiyon listelemesi yapılmış hisseleri almak için kullanılabilir,
    // Buradaki esas listeleme miktarından daha fazla alıcının satıcıdan hisse alamamasıdır
    // Kontroller sonucunda alıcının yolladığı ETH'ler satıcıya, satıcının satmak istediği ve alıcının istediği miktar alıcıya aktarılır
    // Bu işlem sonucunda currentPrice yani mevcut hisse fiyatı güncellenmiş olur
    function directBuy(address from, uint256 amount) public payable {
        // alınacak miktar, satışa sunan kişinin sattığı miktardan fazla mı kontrol et
        require(
            listAmount[from] >= amount,
            "directBuy: Buy amount exceeds listing amount!"
        );

        // satışa sunulan hissenin fiyatını al
        uint256 individualCost = listPrices[from];
        // alınacak miktarla ne kadar edeceğini hesapla / iki miktar da uint256 olduğu için alış miktarını ether'e dönüştürmek gerekli
        uint256 cost = (amount / 10 ** 18) * individualCost;
        // gönderilen ETH miktarı yeterli mi kontrol et
        require(msg.value >= cost, "directBuy: Insufficient funds.");

        // Gönderilen miktarı hisse sahibine yolla
        (bool sent, ) = from.call{value: cost}("");
        // Gönderme statüsünü kontrol et
        require(sent, "directBuy: Unable to send!");
        // Hisseleri alıcıya gönder
        (bool sentVal, ) = address(this).call(
            abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                from,
                msg.sender,
                amount
            )
        );
        require(sentVal, "directBuy: Unable to transfer tokens.");

        // anlık fiyatı güncelle
        currentPrice = individualCost;
        // satışta olan hisse sayısını azalt
        listAmount[from] -= amount;

        emit DirectBuy(msg.sender, from, amount, individualCost);
    }

    // Kontrata kilitli NFT'yi geri almak için kullanılan fonksiyon (sadece bütünlüğü sağlanan hisse sayısı sağlanırsa gerçekleşebilecek fonksiyon)
    function reclaim() external {
        require(
            balanceOf(msg.sender) == totalSupply(),
            "reclaim: Must own total supply of tokens."
        );

        // Kilitli token'i tüm hisselere sahip kişiye yollamak kullanılan metot
        IERC721(_ORIGIN_ADDRESS).transferFrom(
            address(this),
            msg.sender,
            _TOKEN_ID
        );

        emit Reclaim(msg.sender, _ORIGIN_ADDRESS, _TOKEN_ID);
    }

    // Minimum veya maksimum verilebilecek listeleme fiyatını döndürür
    function _calculatePriceRule() internal view returns (uint256, uint256) {
        uint256 currentPricePercentage = (currentPrice * priceRulePercentage) /
            100;

        return (
            currentPrice - currentPricePercentage,
            currentPrice + currentPricePercentage
        );
    }
}
