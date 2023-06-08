# Metatime NFT Marketplace

## Market Yapısı

* Ürün veya koleksiyon oluşturma:
&emsp;Kullanıcılar platform üzerinden kendi NFT'lerini oluşturabilir. Bu özellik iki şekilde olabilir bunlar, tek parça ürün veya bir koleksiyon şeklinde olabilir. Bunu gerçekleştirebilmek için platform kontratıyla kullanıcının etkileşime geçmesi gereklidir.

* NFT Indexing: 
&emsp;Platform üzerinde kullanıcılara kolaylık açısından ağ üzerinde oluşturulmuş NFT kontratların tespit edilmesi gerekmektedir. Bunun için ağ üzerinde belli koşulları sağlayan kontratlar kendi veritabanımızda saklanıp, arayüzümüzde kullanıcıya gösterilebilinir. Bir kontratın NFT koşulunu sağlayan parametreler ise NFT kontratına özgü olan isApprovalAll metodu veya Transfer eventi olabilir. Olası veri kayıplarına karşı çoğu platformda gördüğümüz, arayüz üzerinden veri yenileme özelliği eklenebilir.

* Ürün listeleme:
&emsp;Bir NFT ürünü kullanıcı üç farklı yöntem ile satışa sunabilir. Bunlar; "Direkt Satış", "English Auction" veya "Dutch Auction" şeklinde olabilir.

-&emsp;Direkt Satış: Satıcının ürüne tek bir fiyat verip, alıcının belirtilen fiyatı ödediği zaman gerçekleşen satış tipidir. Bu tip satışta bir zaman kısıtlaması yoktur.

-&emsp;English Auction: Satıcının ürününe minimum bir fiyat verip, belli zaman aralığında alıcıların ürüne teklif yapabildiği açık artırma satışa örnek olabilir.

-&emsp;Dutch Auction: English Auction'a benzemektedir ancak satıcı ürüne direkt satış fiyatı da verebilir, böylece açık artırma süresinde bir alıcı zamana bağlı kalmadan direkt olarak da ürüne sahip olabilir.

&emsp;Her listeleme tipinde de satıcıdan ürünün bulunduğu kontrat üzerinde sahipliğinin aktarılması(approval) gereklidir.

&emsp;Listelemenin kontrat üzerinde mi, yoksa merkezi bir yerde mi saklanması?
Merkezi bir yerde saklamanın, kontrat tarafına göre faydası kullanıcının ağ komisyonunu ödememesi olarak söylenebilir. Böylece daha hızlı ve ücretsiz bir şekilde listelemesini yapabilir. Kontrat haricindeki bu işlemde, kullanıcının cüzdan imzası güvenlik önlemi olarak kullanılabilir. Bu imza güvenli bir ortamda saklanıp kullanıcının bu işlemi yaptığı kanıtlanabilir. Böylelikle ağ dışında güvenli bir ortam oluşur. 

* Teklif mekanizması ve satın alma işlemi:
&emsp;Açık artırma tipindeki listelemelerde ("English Auction", "Dutch Auction" ) alıcı teklifini belirtilen kriterlerde verebilir. Bunlar ürünün minimum teklif fiyatı veya bir önceki tekliften sonra verebileceği minimum miktara göre değişiklik gösterebilir. Direkt satışta ise alıcının, satıcının istediği miktarı direkt olarak vermesi beklenmektedir. Açık artırma listelemelerindeki teklifler, platformun aracı olması ile gerçekleşmektedir. Yani teklifi veren alıcı adayının, teklifte kullandığı birim için platforma alış-veriş yetkisi(approval) vermesi denebilir.

* Teklif için kullanılan birimler:

&emsp;Direkt satışlar ağın birimi (ETH, SOL vs.) veya ERC20 tokenlar ile gerçekleşebilir. Ancak teklif tarafında yetkilendirme(approval) olduğu için ağın birimi ile olması yetkilendirmeyi önlemekte. Bunun için ETH->WETH gibi tokenlar kullanılabilir ve bunun için bir swap mekanızması platform üzerinde geliştirilebilir.

* Satış mekanızması:
&emsp;Direkt satış haricinde, açık artırmalarda ürün sahibi, açık artırma kriterleri içerisinde (zaman veya yüksek teklif), satışın tetiklenmesini sağlayabilir. Satışın doğruluğunun kanıtı için listelenmede satıcının imzası referans alınıp, kontrat üzerinde bu imzanın kontrolü sağlandıktan sonra alış-veriş gerçekleşir.

* Sunucu ve veritabanı:
&emsp;Kullanıcıların platform üzerinde kullanıcı adı, profil resmi, indexlenen NFT koleksiyonları, listelenmeler, teklifler ve imzalar gibi veriler, kendi veritabanımızda saklanabilir. Sunucu tarafında ise imza onayı, imza doğruluğu vb. gibi işlemler güvenliğin sağlanması için kullanılabilir.

* Hisselendirilebilir NFT(Divisible/Fungible Token):
&emsp;Bir NFT ürünün hisselendirilebilmesi iki yöntem ile olabilir. Bunlar; bir ürünü birden çok parçaya bölmek veya bir ürünü yüzdelik parçalara bölmek. 

&emsp;Birden çok parçaya bölmek için NFT'yi tokenize edebilir. Bunun için hisselendirilmek istenilen NFT, bu işlemi gerçekleştiren kontrata aktarılır/kitlenir. Aynı zamanda kontrat istenilen isim, sembol ve arza bağlı olarak NFT'yi hisselendirir. Basılan tüm arz ilk etapta NFT sahibine aktarılır.
Yüzdeli bölmek için ise arz 100'e sabitlenip bunun üzerinden dağıtım gerçekleşebilir.

Hisselendirmeyi sağlayan kontrat yapısı:
&emsp;Kontrat ERC20 kalıtım eden ve bunun dışında hisseleri paylaştırmaya yarayan fonksiyonaliteyi içermektedir. Her hisseli NFT için kontrat deploylamak yerine bir vekil(Proxy) aracılığı ile bu kontratlar kullanılabilir hale getirilebilinir. Proxy kontratları ayarlayan ve bunları indexleyen bir Factory kontrat aracılığı ile hisseli NFT kontratlarının indexlenmesi ve deploylanması sağlanmış olur.

* Arayüz
&emsp;Arayüz tarafında önemli konulardan biri kullanıcıdan cüzdan imzası alınmasıdır. Bunun için web3 veya ethers kütüphanesi ile Metamask veya farklı bir cüzdan ile etkileşime geçilip kullanıcıdan istenilen veriyi imzalaması sağlanabilir.

## Trade Flow
![Marketplace Flow](/resources/marketplace-flow.png "Marketplace Trade Flow")


## Kontrat derleme ve deploy etme

```bash
  npx hardhat compile
  npx hardhat deploy --network networkName
```
    