import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { CONTRACTS } from "../scripts/constants";
import { incrementBlocktimestamp, toWei } from "../scripts/helpers";

const MOCK_ERC721_NAME = "MockERC721";
const TOKEN_URI = "http://thisistest.uri";
const DIVIDED_AMOUNT = 1_000_000;
const DIVISIBLE_NAME = "MockDivisible";
const DIVISIBLE_SYMBOL = "mDIV";
const SALE_PRICE = 1;
// 1 dakika
const SALE_LENGTH = 60;
const SALE_AMOUNT = 1_000;
const SHAREHOLDER_BUY_AMOUNT = 10;
const LIST_PRICE = 1.05;
const MAX_INT =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

describe("Divisible", function () {
  async function initiateVariables() {
    const [deployer, curator, shareholder_1, shareholder_2] =
      await ethers.getSigners();

    const Divisible = await ethers.getContractFactory(
      CONTRACTS.utils.Divisible
    );
    const MockERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721
    );
    const divisible = await Divisible.connect(curator).deploy();
    const mockERC721 = await MockERC721.connect(deployer).deploy();

    return {
      divisible,
      mockERC721,
      deployer,
      curator,
      shareholder_1,
      shareholder_2,
    };
  }

  describe("Initiate", async () => {
    it("Initiate divisible contract & presale", async function () {
      const {
        divisible,
        mockERC721,
        deployer,
        curator,
        shareholder_1,
        shareholder_2,
      } = await loadFixture(initiateVariables);

      await mockERC721.connect(deployer).mintItem(curator.address, TOKEN_URI);

      expect(await mockERC721.name()).to.equal(MOCK_ERC721_NAME);
      expect(await mockERC721.ownerOf(0)).to.equal(curator.address);

      await divisible.connect(curator).approve(divisible.address, MAX_INT);

      // Divisible kontratını başlat (initiate fonksiyonunu belirt)
      await mockERC721
        .connect(curator)
        .transferFrom(curator.address, divisible.address, 0);
      await divisible
        .connect(curator)
        .initialize(
          curator.address,
          mockERC721.address,
          0,
          toWei(DIVIDED_AMOUNT.toString()),
          DIVISIBLE_NAME,
          DIVISIBLE_SYMBOL
        );

      expect(await divisible.name()).to.equal(DIVISIBLE_NAME);

      const balanceOfCurator = await divisible.balanceOf(curator.address);
      const approvalOfCurator = await divisible.allowance(
        curator.address,
        divisible.address
      );

      // Ön satışı başlatan fonksiyon
      await divisible
        .connect(curator)
        .startSale(
          toWei(SALE_PRICE.toString()),
          SALE_LENGTH,
          toWei(SALE_AMOUNT.toString())
        );

      const promiseAllSaleInfo = await Promise.all([
        await divisible.saleStatus(),
        await divisible.saleLength(),
        await divisible.startBlock(),
        await divisible.salePrice(),
        await divisible.currentPrice(),
        await divisible.saleAmount(),
      ]);

      // Önsatış bilgileri + etkilediği kontrat değerleri
      const [
        saleStatus,
        saleLength,
        startBlock,
        salePrice,
        currentPrice,
        saleAmount,
      ] = promiseAllSaleInfo;

      const sendValue = toWei((SHAREHOLDER_BUY_AMOUNT * SALE_PRICE).toString());

      await divisible
        .connect(shareholder_1)
        .buyDivisibleFromSale(toWei(SHAREHOLDER_BUY_AMOUNT.toString()), {
          value: sendValue,
        });

      const divisibleBalanceOfShareholder_1 = await divisible.balanceOf(
        shareholder_1.address
      );

      // Aktif bir listelemeyi bitirirken revert senaryosunu dene
      await expect(divisible.connect(curator).endSale()).revertedWith(
        "endSale: Sale has to be finished to make this action."
      );

      // Listeleme süresini geçmek için hardhat test suite'in block.timestamp'ini artır
      await incrementBlocktimestamp(ethers, SALE_LENGTH + 30);

      await divisible.connect(curator).endSale();

      // Satılan miktarı, hissedarın aldığı miktar ile karşılaştır, tek hissedar olduğu için toplamda satılan miktarla aynı olmalı
      expect(await divisible.soldAmount()).to.equal(
        toWei(SHAREHOLDER_BUY_AMOUNT.toString())
      );

      // Listeleme için kullanıcının platforma tokenlarını approve etmesi gerekli
      await divisible
        .connect(shareholder_1)
        .approve(divisible.address, MAX_INT);

      // Fiyat kuralını ihlal eden listelemeyi dene
      await expect(
        divisible
          .connect(shareholder_1)
          .list(toWei(SHAREHOLDER_BUY_AMOUNT.toString()), 2)
      ).revertedWith("list: Must ensure price rule.");

      await divisible
        .connect(shareholder_1)
        .list(
          toWei(SHAREHOLDER_BUY_AMOUNT.toString()),
          toWei(LIST_PRICE.toString())
        );

      const listDataFromShareholder1 = await Promise.all([
        await divisible.listPrices(shareholder_1.address),
        await divisible.listAmount(shareholder_1.address),
      ]);

      console.log({
        listPrice: listDataFromShareholder1[0],
        listAmount: listDataFromShareholder1[1],
      });

      expect(listDataFromShareholder1[0]).to.equal(
        toWei(LIST_PRICE.toString())
      );
      expect(listDataFromShareholder1[1]).to.equal(
        toWei(SHAREHOLDER_BUY_AMOUNT.toString())
      );

      const listedSharePrice = await divisible.listPrices(
        shareholder_1.address
      );

      const cost =
        (parseFloat(ethers.utils.formatEther(listedSharePrice.toString())) *
          SHAREHOLDER_BUY_AMOUNT) /
        2;

      await divisible
        .connect(shareholder_2)
        .directBuy(
          shareholder_1.address,
          toWei((SHAREHOLDER_BUY_AMOUNT / 2).toString()),
          { value: toWei(cost.toString()) }
        );

      const shareholder_2Balance = await divisible.balanceOf(
        shareholder_2.address
      );

      // Shareholder 2 adresine istenilen miktar yollanmış mı kontrol et
      expect(shareholder_2Balance).to.equal(
        toWei((SHAREHOLDER_BUY_AMOUNT / 2).toString())
      );

      await divisible.connect(shareholder_1).cancelListing();

      const shareholder1ListingInfo = await Promise.all([
        await divisible.listPrices(shareholder_1.address),
        await divisible.listAmount(shareholder_1.address),
      ]);

      expect(shareholder1ListingInfo).to.deep.equal([
        ethers.BigNumber.from(0),
        ethers.BigNumber.from(0),
      ]);
    });
  });
});
