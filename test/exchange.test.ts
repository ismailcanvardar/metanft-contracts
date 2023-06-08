import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers, network } from "hardhat";
import { CONTRACTS } from "../scripts/constants";
import SignatureHelper, {
  IBid,
  IDomain,
  IListing,
  ISignatureHelper,
} from "../scripts/signature-helper";
import {
  getBlockTimestamp,
  toWei,
  createBidTuple,
  createListingTuple,
  callMethod,
  calculateExchangeFee,
} from "../scripts/helpers";

const MOCK_ERC721_NAME = "MockERC721";
const TOKEN_URI = "http://thisistest.uri";
const SEVEN_DAYS = 7 * 24 * 60 * 60;
const MOCK_LISTING_PRICE = 1;
const MOCK_BID_PRICE = 2;
const MOCK_SOFT_CAP = 1;
const MOCK_HARD_CAP = 2;
const MOCK_ERC20_INITIAL_SUPPLY = 1_000_000;
const MOCK_ERC20_TRANSFER_AMOUNT = 5_000;
const MAX_INT =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";
const FINALIZE_AUCTION_METHOD_NAME = "finalizeAuction";
const DIRECT_BUY__METHOD_NAME = "directBuy";
const EXCHANGE_FEE_PERCENTAGE = 5;

describe("Exchange", function () {
  // Test suiteler için gerekli verilerin sağlanması
  async function initiateVariables() {
    const [
      deployer,
      seller_1,
      buyer_1,
      seller_2,
      buyer_2,
      account_1,
      account_2,
      account_3,
      fee_collector,
    ] = await ethers.getSigners();

    const Exchange = await ethers.getContractFactory(CONTRACTS.core.Exchange);
    const ExchangeConfig = await ethers.getContractFactory(
      CONTRACTS.helpers.ExchangeConfig
    );
    const MockERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721!
    );
    const MockERC20 = await ethers.getContractFactory(CONTRACTS.mocks.MockERC20!);
    const exchangeConfig = await ExchangeConfig.connect(deployer).deploy();
    const exchange = await Exchange.connect(deployer).deploy(
      fee_collector.address,
      exchangeConfig.address
    );
    const mockERC721 = await MockERC721.connect(deployer).deploy();
    const mockERC20 = await MockERC20.connect(deployer).deploy(
      toWei(MOCK_ERC20_INITIAL_SUPPLY.toString())
    );

    // EIP-712 için gerekli imza domain'i
    const verifierDomain: IDomain = {
      chainId: network.config.chainId as number,
      name: "Metatime",
      verifyingContract: exchange.address,
      version: "1.0",
    };

    const signatureHelper: ISignatureHelper = new SignatureHelper(
      verifierDomain
    );

    return {
      exchange,
      mockERC721,
      mockERC20,
      deployer,
      seller_1,
      buyer_1,
      seller_2,
      buyer_2,
      account_1,
      account_2,
      account_3,
      signatureHelper,
      fee_collector,
    };
  }

  describe("Deployment", function () {
    it("Should set the right unlockTime", async function () {
      const { exchange, mockERC721, deployer } = await loadFixture(
        initiateVariables
      );

      expect(await exchange.owner()).to.equal(deployer.address);
      expect(await mockERC721.name()).to.equal(MOCK_ERC721_NAME);
    });
  });

  describe("Set Listing & Buy Item", async function () {
    it("Should generate signature and sign it", async function () {
      const {
        exchange,
        mockERC721,
        deployer,
        seller_1,
        buyer_1,
        mockERC20,
        signatureHelper,
      } = await loadFixture(initiateVariables);

      // Mints token with the id of 1
      await mockERC721.connect(deployer).mintItem(seller_1.address, TOKEN_URI);
      // Mints token with the id of 2
      await mockERC721.connect(deployer).mintItem(seller_1.address, TOKEN_URI);

      expect(await mockERC721.ownerOf(0)).equal(seller_1.address);
      expect(await mockERC721.ownerOf(1)).equal(seller_1.address);

      const blockTimestamp = await getBlockTimestamp(ethers);

      const sellerNonce = await exchange.fetchNonce(seller_1.address);
      const buyerNonce = await exchange.fetchNonce(buyer_1.address);

      const pseudoEnglishListing: IListing = {
        originAddress: mockERC721.address,
        tokenId: 0,
        seller: seller_1.address,
        startTimestamp: blockTimestamp,
        endTimestamp: 0,
        softCap: toWei(MOCK_LISTING_PRICE.toString()),
        hardCap: ethers.BigNumber.from(0),
        isERC20: true,
        erc20TokenAddress: mockERC20.address,
        listingType: 1,
      };

      const pseudoDutchListing: IListing = {
        originAddress: mockERC721.address,
        tokenId: 1,
        seller: seller_1.address,
        startTimestamp: blockTimestamp,
        endTimestamp: blockTimestamp + SEVEN_DAYS,
        softCap: toWei(MOCK_LISTING_PRICE.toString()),
        hardCap: toWei(MOCK_LISTING_PRICE.toString()),
        isERC20: true,
        erc20TokenAddress: mockERC20.address,
        listingType: 2,
      };

      const pseduoBidForEnglish: IBid = {
        originAddress: mockERC721.address,
        tokenId: 0,
        bidder: buyer_1.address,
        bidAmount: toWei(MOCK_BID_PRICE.toString()),
        isERC20: true,
        erc20TokenAddress: mockERC20.address,
      };

      const pseudoBidForDutch: IBid = {
        originAddress: mockERC721.address,
        tokenId: 1,
        bidder: buyer_1.address,
        bidAmount: toWei(MOCK_BID_PRICE.toString()),
        isERC20: true,
        erc20TokenAddress: mockERC20.address,
      };

      const signatures = await Promise.all([
        // Signing message for listing type 1
        await signatureHelper.signListing(
          seller_1,
          pseudoEnglishListing,
          sellerNonce
        ),
        // Signing message for listing type 2
        await signatureHelper.signListing(
          seller_1,
          pseudoDutchListing,
          sellerNonce
        ),
        // // Signing bid message for listing type 1
        await signatureHelper.signBid(buyer_1, pseduoBidForEnglish, buyerNonce),
        // // Signing bid message for listing type 2
        await signatureHelper.signBid(buyer_1, pseudoBidForDutch, buyerNonce),
        // Empty signature
        await buyer_1.signMessage("Empty Signature"),
      ]);

      const listingSignatureForEnglish = signatures[0];
      const listingSignatureForDutch = signatures[1];
      const bidSignatureForEnglish = signatures[2];
      const bidSignatureForDutch = signatures[3];
      const emptySignature = signatures[4];

      console.table({
        listingSignatureForEnglish,
        listingSignatureForDutch,
        bidSignatureForEnglish,
        bidSignatureForDutch,
        emptySignature,
      });

      const listingTupleForEnglish = createListingTuple(pseudoEnglishListing);
      const listingTupleForDutch = createListingTuple(pseudoDutchListing);
      const bidTupleForEnglish = createBidTuple(pseduoBidForEnglish);
      const bidTupleForDutch = createBidTuple(pseudoBidForDutch);

      // Yanlış listeleme imzası test et
      await expect(
        callMethod(exchange, seller_1, FINALIZE_AUCTION_METHOD_NAME, [
          listingTupleForEnglish,
          bidTupleForEnglish,
          [emptySignature, bidSignatureForEnglish],
          [sellerNonce, buyerNonce],
        ])
      ).to.be.revertedWith("_verifyListing: Invalid Signature.");

      // // Yanlış teklif imzası test et
      await expect(
        callMethod(exchange, seller_1, FINALIZE_AUCTION_METHOD_NAME, [
          listingTupleForEnglish,
          bidTupleForEnglish,
          [listingSignatureForEnglish, emptySignature],
          [sellerNonce, buyerNonce],
        ])
      ).to.be.revertedWith("_verifyBid: Invalid Signature.");

      // NFT ürünü için platformu yetkilendir
      await mockERC721
        .connect(seller_1)
        .setApprovalForAll(exchange.address, true);

      // Yetkilendirmeyi kontrol et
      expect(
        await mockERC721
          .connect(seller_1)
          .isApprovedForAll(seller_1.address, exchange.address)
      ).to.be.equal(true);

      // Teklif veren kişinin teklif yetkilendirmesini kontrol et
      await expect(
        callMethod(exchange, seller_1, FINALIZE_AUCTION_METHOD_NAME, [
          listingTupleForEnglish,
          bidTupleForEnglish,
          [listingSignatureForEnglish, bidSignatureForEnglish],
          [sellerNonce, buyerNonce],
        ])
      ).to.be.revertedWith("exchange: Needs to approve tokens!");

      // Teklif veren kişinin tokenları için yetkilendirme yap
      await mockERC20.connect(buyer_1).approve(exchange.address, MAX_INT);

      // Teklif verenin yetersiz bakiyesini test et
      await expect(
        callMethod(exchange, seller_1, FINALIZE_AUCTION_METHOD_NAME, [
          listingTupleForEnglish,
          bidTupleForEnglish,
          [listingSignatureForEnglish, bidSignatureForEnglish],
          [sellerNonce, buyerNonce],
        ])
      ).to.be.revertedWith("ERC20: transfer amount exceeds balance");

      // Alıcının adresine MOCK_ERC20_TRANSFER_AMOUNT kadar token yolla
      await mockERC20
        .connect(deployer)
        .transfer(
          buyer_1.address,
          toWei(MOCK_ERC20_TRANSFER_AMOUNT.toString())
        );

      // Alıcnın bakiyesi güncellenmiş mi test et
      expect(await mockERC20.balanceOf(buyer_1.address)).to.be.equal(
        toWei(MOCK_ERC20_TRANSFER_AMOUNT.toString())
      );

      const balanceOfBuyerBeforeTx = await mockERC20.balanceOf(buyer_1.address);
      // console.log("BALANCE OF BUYER BEFORE TX", balanceOfBuyerBeforeTx);

      // Başarılı senaryoyu test et
      await callMethod(exchange, seller_1, FINALIZE_AUCTION_METHOD_NAME, [
        listingTupleForEnglish,
        bidTupleForEnglish,
        [listingSignatureForEnglish, bidSignatureForEnglish],
        [sellerNonce, buyerNonce],
      ]);

      // Listelenmenin bitiminden sonra balance ları ve ürün sahibini kontrol et
      const balanceOfBuyerAfterTx = await mockERC20.balanceOf(buyer_1.address);
      const balanceOfSellerAfterTx = await mockERC20.balanceOf(
        seller_1.address
      );
      const ownerOfItemAfterTx = await mockERC721.ownerOf(0);

      // console.log("BALANCE OF BUYER AFTER TX", balanceOfBuyerAfterTx);
      // console.log(
      //   "EXCHANGE FEE",
      //   calculateExchangeFee(MOCK_BID_PRICE, EXCHANGE_FEE_PERCENTAGE)
      // );

      expect(balanceOfBuyerAfterTx).to.be.equal(
        toWei(
          (
            MOCK_ERC20_TRANSFER_AMOUNT -
            (calculateExchangeFee(MOCK_BID_PRICE, EXCHANGE_FEE_PERCENTAGE) +
              MOCK_BID_PRICE)
          ).toString()
        )
      );
      expect(balanceOfSellerAfterTx).to.be.equal(
        toWei(MOCK_BID_PRICE.toString())
      );
      expect(ownerOfItemAfterTx).to.be.equal(buyer_1.address);
    });

    it("Should do direct buy for direct sale and dutch auction", async () => {
      const {
        exchange,
        mockERC721,
        deployer,
        seller_1,
        buyer_1,
        buyer_2,
        seller_2,
        mockERC20,
        signatureHelper,
        fee_collector,
      } = await loadFixture(initiateVariables);

      const blockTimestamp = await getBlockTimestamp(ethers);

      // İki adet NFT üret
      await mockERC721.connect(deployer).mintItem(seller_1.address, TOKEN_URI);
      await mockERC721.connect(deployer).mintItem(seller_2.address, TOKEN_URI);

      // NFT ürünü için platformu yetkilendir
      await mockERC721
        .connect(seller_1)
        .setApprovalForAll(exchange.address, true);

      await mockERC721
        .connect(seller_2)
        .setApprovalForAll(exchange.address, true);

      // Yetkilendirmeyi kontrol et
      expect(
        await mockERC721
          .connect(seller_1)
          .isApprovedForAll(seller_1.address, exchange.address)
      ).to.be.equal(true);

      await mockERC20
        .connect(deployer)
        .transfer(
          buyer_2.address,
          toWei(MOCK_ERC20_TRANSFER_AMOUNT.toString())
        );

      // Direkt satın almak için listeleme objesi oluştur
      const pseudoDirectListing: IListing = {
        originAddress: mockERC721.address,
        tokenId: 0,
        seller: seller_1.address,
        startTimestamp: blockTimestamp,
        endTimestamp: 0,
        softCap: toWei(MOCK_LISTING_PRICE.toString()),
        hardCap: toWei(MOCK_LISTING_PRICE.toString()),
        isERC20: false,
        erc20TokenAddress: ethers.constants.AddressZero,
        listingType: 0,
      };

      // Dutch auction için listeleme objesi oluştur
      const pseudoDutchListing: IListing = {
        originAddress: mockERC721.address,
        tokenId: 1,
        seller: seller_2.address,
        startTimestamp: blockTimestamp,
        endTimestamp: blockTimestamp + SEVEN_DAYS,
        softCap: toWei(MOCK_SOFT_CAP.toString()),
        hardCap: toWei(MOCK_HARD_CAP.toString()),
        isERC20: true,
        erc20TokenAddress: mockERC20.address,
        listingType: 2,
      };

      const seller1Nonce = await exchange.fetchNonce(seller_1.address);
      const seller2Nonce = await exchange.fetchNonce(seller_2.address);

      // Listelemeler için imza oluştur
      const signatures = await Promise.all([
        // Signing message for listing type 1
        await signatureHelper.signListing(
          seller_1,
          pseudoDirectListing,
          seller1Nonce
        ),
        // Signing message for listing type 2
        await signatureHelper.signListing(
          seller_2,
          pseudoDutchListing,
          seller2Nonce
        ),
        // Empty signature
        await buyer_1.signMessage("Empty Signature"),
      ]);

      const listingSignatureForDirect = signatures[0];
      const listingSignatureForDutch = signatures[1];
      const emptySignature = signatures[2];

      console.table({
        listingSignatureForDirect,
        listingSignatureForDutch,
        emptySignature,
      });

      const directListingTuple = createListingTuple(pseudoDirectListing);
      const dutchListingTuple = createListingTuple(pseudoDutchListing);

      const feeCollectorBalanceBeforeDirectTx =
        await ethers.provider.getBalance(fee_collector.address);
      const sellerBalanceBeforeDirectTx = await ethers.provider.getBalance(
        seller_1.address
      );

      // Direkt alış metodunu tetikle
      await callMethod(
        exchange,
        buyer_1,
        DIRECT_BUY__METHOD_NAME,
        [
          directListingTuple,
          listingSignatureForDirect,
          toWei(MOCK_LISTING_PRICE.toString()),
          seller1Nonce,
        ],
        toWei(
          (
            MOCK_LISTING_PRICE +
            calculateExchangeFee(MOCK_LISTING_PRICE, EXCHANGE_FEE_PERCENTAGE)
          ).toString()
        )
      );

      const feeCollectorBalanceAfterDirectTx = await ethers.provider.getBalance(
        fee_collector.address
      );
      const sellerBalanceAfterDirectTx = await ethers.provider.getBalance(
        seller_1.address
      );

      const exchangeFee = toWei(
        calculateExchangeFee(
          MOCK_LISTING_PRICE,
          EXCHANGE_FEE_PERCENTAGE
        ).toString()
      );

      // FeeCollector'a komisyon gitmiş mi kontrol et
      expect(feeCollectorBalanceAfterDirectTx).to.equal(
        ethers.BigNumber.from(exchangeFee).add(
          ethers.BigNumber.from(feeCollectorBalanceBeforeDirectTx)
        )
      );

      // Satıcıya parası gitmiş mi kontrol et
      expect(sellerBalanceAfterDirectTx).to.equal(
        ethers.BigNumber.from(toWei(MOCK_LISTING_PRICE.toString())).add(
          ethers.BigNumber.from(sellerBalanceBeforeDirectTx)
        )
      );

      await mockERC20.connect(buyer_2).approve(exchange.address, MAX_INT);

      const sellerBalanceBeforeDutchTx = await mockERC20.balanceOf(
        seller_2.address
      );
      const feeCollecterBalanceBeforeDutchTx = await mockERC20.balanceOf(
        fee_collector.address
      );

      // Dutch listeleme alış metodunu tetikle
      await callMethod(
        exchange,
        buyer_2,
        DIRECT_BUY__METHOD_NAME,
        [
          dutchListingTuple,
          listingSignatureForDutch,
          toWei(MOCK_HARD_CAP.toString()),
          seller2Nonce,
        ],
        toWei(
          (
            MOCK_HARD_CAP +
            calculateExchangeFee(MOCK_HARD_CAP, EXCHANGE_FEE_PERCENTAGE)
          ).toString()
        )
      );

      const sellerBalanceAfterDutchTx = await mockERC20.balanceOf(
        seller_2.address
      );
      const feeCollecterBalanceAfterDutchTx = await mockERC20.balanceOf(
        fee_collector.address
      );

      // FeeCollector'a komisyon gitmiş mi kontrol et
      expect(feeCollecterBalanceAfterDutchTx).to.equal(
        ethers.BigNumber.from(
          toWei(
            calculateExchangeFee(
              MOCK_HARD_CAP,
              EXCHANGE_FEE_PERCENTAGE
            ).toString()
          )
        ).add(ethers.BigNumber.from(feeCollecterBalanceBeforeDutchTx))
      );

      // FeeCollector'a komisyon gitmiş mi kontrol et
      expect(sellerBalanceAfterDutchTx).to.equal(
        ethers.BigNumber.from(toWei(MOCK_HARD_CAP.toString())).add(
          ethers.BigNumber.from(sellerBalanceBeforeDutchTx)
        )
      );
    });
  });

  // describe("Calculate timestamps", async function () {
  //   const sevenDays = 7 * 24 * 60 * 60;

  //   const blockNumBefore = await ethers.provider.getBlockNumber();
  //   const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  //   const timestampBefore = blockBefore.timestamp;

  //   await ethers.provider.send("evm_increaseTime", [sevenDays]);
  //   await ethers.provider.send("evm_mine", []);

  //   const blockNumAfter = await ethers.provider.getBlockNumber();
  //   const blockAfter = await ethers.provider.getBlock(blockNumAfter);
  //   const timestampAfter = blockAfter.timestamp;

  //   // console.log(timestampBefore);
  //   // console.log(timestampAfter);

  //   expect(blockNumAfter).to.be.equal(blockNumBefore + 1);
  //   expect(timestampAfter).to.be.equal(timestampBefore + sevenDays);
  //   getBlockTimestamp(ethers).then(/*console.log*/);
  // });
});
