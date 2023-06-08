import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { CONTRACTS } from "../scripts/constants";
import { callMethod } from "../scripts/helpers";

const FRACTIONAL_NAME = "MockDivisible";
const FRACTIONAL_SYMBOL = "mDIV";
const FRACTIONALIZE_METHOD_NAME = "fractionalize";
const TOKEN_URI = "http://thisistest.uri";
const TOKEN_URIS = Array(3).fill(TOKEN_URI);

describe("FractionalProxyManager", function () {
  async function initiateVariables() {
    const [deployer, nft_owner_1, nft_owner_2, shareholder_1, shareholder_2] =
      await ethers.getSigners();

    const MockERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721
    );
    const FractionalProxyManager = await ethers.getContractFactory(
      CONTRACTS.utils.FractionalProxyManager
    );
    const mockERC721 = await MockERC721.deploy();
    const fractionalProxyManager = await FractionalProxyManager.connect(
      deployer
    ).deploy();

    return {
      fractionalProxyManager,
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
      const { fractionalProxyManager, deployer } = await loadFixture(
        initiateVariables
      );

      // Owner'ı kontrol et
      expect(await fractionalProxyManager.owner()).to.equal(deployer.address);
    });
  });

  describe("Deploying Proxy Contracts", async () => {
    it("Should create proxy divisible contract", async () => {
      const {
        fractionalProxyManager,
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
      const validFractionalizeFuncParams = [
        mockERC721.address,
        0,
        TOKEN_URIS,
        FRACTIONAL_NAME,
        FRACTIONAL_SYMBOL,
      ];

      // NFT sahibi DivisibleProxyManager için approve yetkisi vermediği için revert olması beklenen senaryo
      await expect(
        callMethod(
          fractionalProxyManager,
          nft_owner_1,
          FRACTIONALIZE_METHOD_NAME,
          validFractionalizeFuncParams
        )
      ).reverted;

      // Her iki nft sahibi için approval yap
      await mockERC721
        .connect(nft_owner_1)
        .setApprovalForAll(fractionalProxyManager.address, true);
      await mockERC721
        .connect(nft_owner_2)
        .setApprovalForAll(fractionalProxyManager.address, true);

      // Başarılı senaryoyu dene
      await callMethod(
        fractionalProxyManager,
        nft_owner_1,
        FRACTIONALIZE_METHOD_NAME,
        validFractionalizeFuncParams
      );

      // Toplam hisselendirilen token sayısını al - hisselendirilen token için oluşturulan proxy kontratı çekmek için gerekli
      const fractionalCount = await fractionalProxyManager.fractionalCount();

      // Hisselendirilen token'in proxy kontrat adresini al
      const lastDividedTokenProxyAddress =
        await fractionalProxyManager.fractionals(
          ethers.BigNumber.from(fractionalCount).sub(ethers.BigNumber.from(1))
        );

      // console.log(lastDividedTokenProxyAddress);

      // Proxy kontratı adresinden çek - böylelikle gelecek işlemleri bu instance üzerinden yap
      const Fractional = await ethers.getContractFactory(
        CONTRACTS.utils.Fractional
      );
      const fractionalContract = Fractional.attach(
        lastDividedTokenProxyAddress
      );

      // console.log(fractionalContract);

      // Kontrat için basılan token miktarını kontrol et
      expect(await fractionalContract.balanceOf(nft_owner_1.address)).to.equal(
        TOKEN_URIS.length
      );

      // Hisselendirilmiş kontrattaki NFT'yi kontrol et
      expect(await mockERC721.ownerOf(0)).to.equal(fractionalContract.address);
    });
  });
});
