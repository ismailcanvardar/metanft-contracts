import { time, loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { CONTRACTS } from "../scripts/constants";
import { callMethod, toWei } from "../scripts/helpers";

const LOGIC_ADDRESS: string = "0xa16E02E87b7454126E5E10d957A927A7F5B5d2be";
const DIVIDED_AMOUNT = 1_000_000;
const DIVISIBLE_NAME = "MockDivisible";
const DIVISIBLE_SYMBOL = "mDIV";
const DIVIDE_METHOD_NAME = "divide";
const SENT_DIVISIBLE_AMOUNT = 1_000;
const SHARE_PERCENTAGE = 0.1;

describe("DivisibleProxyManager", function () {
  async function initiateVariables() {
    const [deployer, nft_owner_1, nft_owner_2, shareholder_1, shareholder_2] =
      await ethers.getSigners();

    const MockERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721
    );
    const DivisibleProxyManager = await ethers.getContractFactory(
      CONTRACTS.utils.DivisibleProxyManager
    );
    const mockERC721 = await MockERC721.deploy();
    const divisibleProxyManager = await DivisibleProxyManager.connect(
      deployer
    ).deploy();

    return {
      divisibleProxyManager,
      deployer,
      mockERC721,
      nft_owner_1,
      nft_owner_2,
      shareholder_1,
      shareholder_2,
    };
  }

  describe("Deployment", async () => {
    it("Should check", async function () {
      const { divisibleProxyManager, deployer } = await loadFixture(
        initiateVariables
      );

      // Owner'ı kontrol et
      expect(await divisibleProxyManager.owner()).to.equal(deployer.address);
    });
  });

  describe("Deploying Proxy Contracts", async () => {
    it("Should create proxy divisible contract", async () => {
      const {
        divisibleProxyManager,
        deployer,
        mockERC721,
        nft_owner_1,
        nft_owner_2,
        shareholder_1,
      } = await loadFixture(initiateVariables);

      // Verilen adreslere NFT token üret
      await mockERC721
        .connect(deployer)
        .mintItem(nft_owner_1.address, "test.com");
      await mockERC721
        .connect(deployer)
        .mintItem(nft_owner_2.address, "test.com");

      // Hisselendirme fonksiyonu için gerekli geçerli parametre değerleri
      const validDivideFuncParams = [
        mockERC721.address,
        0,
        toWei(DIVIDED_AMOUNT.toString()),
        DIVISIBLE_NAME,
        DIVISIBLE_SYMBOL,
      ];

      // NFT sahibi DivisibleProxyManager için approve yetkisi vermediği için revert olması beklenen senaryo
      await expect(
        callMethod(
          divisibleProxyManager,
          nft_owner_1,
          DIVIDE_METHOD_NAME,
          validDivideFuncParams
        )
      ).reverted;

      // Her iki nft sahibi için approval yap
      await mockERC721
        .connect(nft_owner_1)
        .setApprovalForAll(divisibleProxyManager.address, true);
      await mockERC721
        .connect(nft_owner_2)
        .setApprovalForAll(divisibleProxyManager.address, true);

      // Başarılı senaryoyu dene
      await callMethod(
        divisibleProxyManager,
        nft_owner_1,
        DIVIDE_METHOD_NAME,
        validDivideFuncParams
      );

      // Toplam hisselendirilen token sayısını al - hisselendirilen token için oluşturulan proxy kontratı çekmek için gerekli
      const divisibleCount = await divisibleProxyManager.divisibleCount();

      // Hisselendirilen token'in proxy kontrat adresini al
      const lastDividedTokenProxyAddress =
        await divisibleProxyManager.divisibles(
          ethers.BigNumber.from(divisibleCount).sub(ethers.BigNumber.from(1))
        );

      // console.log(lastDividedTokenProxyAddress);

      // Proxy kontratı adresinden çek - böylelikle gelecek işlemleri bu instance üzerinden yap
      const Divisible = await ethers.getContractFactory(
        CONTRACTS.utils.Divisible
      );
      const divisibleContract = Divisible.attach(lastDividedTokenProxyAddress);

      // console.log(divisibleContract);

      // Kontrat için basılan token miktarını kontrol et
      expect(await divisibleContract.totalSupply()).to.equal(
        toWei(DIVIDED_AMOUNT.toString())
      );

      // Hisselendirilmiş kontrattaki NFT'yi kontrol et
      expect(await mockERC721.ownerOf(0)).to.equal(divisibleContract.address);

      // getItemInfo'dan gelen NFT bilgisini karşılaştır
      const itemInfo = await divisibleContract.getItemInfo();
      expect(itemInfo).to.deep.equal([
        mockERC721.address,
        ethers.BigNumber.from(0),
        nft_owner_1.address,
      ]);

      // Kontrattan hissedara ERC20 token yolla
      await divisibleContract
        .connect(nft_owner_1)
        .transfer(
          shareholder_1.address,
          toWei(SENT_DIVISIBLE_AMOUNT.toString())
        );

      // Hissedara SENT_DIVISIBLE_AMOUNT kadar token gönderildiğini kontrol et
      expect(await divisibleContract.balanceOf(shareholder_1.address)).to.equal(
        toWei(SENT_DIVISIBLE_AMOUNT.toString())
      );

      // Hissedarın yüzdeliğini hesapla
      const shareholder_1Balance = await divisibleContract.balanceOf(
        shareholder_1.address
      );
      const totalSupply = await divisibleContract.totalSupply();

      // 1 * 100 / 100  => share holder balance * total supply / 100
      const sharePercentage = (shareholder_1Balance / totalSupply) * 100;
      expect(sharePercentage).to.equal(SHARE_PERCENTAGE);

      // Toplam hisseleri bulunduran kişi olmadığı için reclaim işlemini yapamaz
      await expect(divisibleContract.connect(nft_owner_1).reclaim()).revertedWith("reclaim: Must own total supply of tokens.");

      // Hissedar elindeki miktarı nft owner yani hisseli oluşturan elemana attığı senaryo, böylece tüm hisselere nft owner sahip olur,
      // ardından reclaim metodunu çalıştırabilir
      await divisibleContract.connect(shareholder_1).transfer(nft_owner_1.address, toWei(SENT_DIVISIBLE_AMOUNT.toString()));

      // Başarılı reclaim senaryosu
      await divisibleContract.connect(nft_owner_1).reclaim();

      // Reclaim ettikten sonra nft kime geçmiş kontrol et
      expect(await mockERC721.ownerOf(0)).to.equal(nft_owner_1.address);
    });
  });
});
