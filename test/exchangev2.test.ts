import { expect } from "chai";
import { ethers, network } from "hardhat";
import { CONTRACTS, CONSTRUCTOR_PARAMS } from "../scripts/constants";
import {
  getBlockTimestamp,
  incrementBlocktimestamp,
  toWei,
} from "../scripts/helpers";
import { IDomain, TypedDataSignature, IEIP712BidTypes, IEIP712ListingTypes } from "@metatime/signature-provider";
import { Wallet } from "ethers";

const MOCK_ERC20_INITIAL_SUPPLY = toWei(String(100_000_000));
const WETH_INITIAL_SUPPLY = toWei(String(100_000_000));
const EXAMPLE_TOKEN_URI = "https://examp.le";
const MOCK_ERC20_SENT_AMOUNT = toWei(String(100_000));

describe("Exchange", function () {
  // Initiate variables
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

    // Prepare contracts
    const Affiliate = await ethers.getContractFactory(CONTRACTS.utils.Affiliate);
    const Exchange = await ethers.getContractFactory(CONTRACTS.core.Exchange);
    const ExchangeConfig = await ethers.getContractFactory(
      CONTRACTS.helpers.ExchangeConfig
    );
    const RoyaltyFeeManager = await ethers.getContractFactory(
      CONTRACTS.helpers.RoyaltyFeeManager
    );
    const MOCK_ERC20 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC20!,
    );
    const MOCK_ERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721!,
    );
    const WETH = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC20!,
    );
    const MULTICALL = await ethers.getContractFactory(
      CONTRACTS.utils.Multicall
    );

    // Deploy contracts
    const affiliate = await Affiliate.connect(deployer).deploy();
    const exchangeConfig = await ExchangeConfig.connect(deployer).deploy();
    const royaltyFeeManager = await RoyaltyFeeManager.connect(deployer).deploy(
      1_000
    );
    const weth = await WETH.connect(deployer).deploy(WETH_INITIAL_SUPPLY);
    const exchange = await Exchange.connect(deployer).deploy(
      fee_collector.address,
      affiliate.address,
      exchangeConfig.address,
      royaltyFeeManager.address,
      weth.address
    );
    const multicall = await MULTICALL.connect(deployer).deploy();
    const mockErc20 = await MOCK_ERC20.connect(deployer).deploy(MOCK_ERC20_INITIAL_SUPPLY);
    const mockErc721 = await MOCK_ERC721.connect(deployer).deploy();
    const domain: IDomain = {
      chainId: network.config.chainId!,
      name: "Metatime",
      verifyingContract: exchange.address,
      version: "1.0"
    };
    const typedDataSignatureForSeller = new TypedDataSignature(seller_1 as unknown as Wallet, domain);
    const typedDataSignatureForBuyer = new TypedDataSignature(buyer_1 as unknown as Wallet, domain);

    return {
      deployer,
      seller_1,
      buyer_1,
      seller_2,
      buyer_2,
      account_1,
      account_2,
      account_3,
      fee_collector,
      affiliate,
      exchangeConfig,
      royaltyFeeManager,
      weth,
      exchange,
      multicall,
      mockErc20,
      mockErc721,
      typedDataSignatureForSeller,
      typedDataSignatureForBuyer
    };
  }

  describe("Deployment", function () {
    it("Should direct buy asset", async function () {
      const { deployer, seller_1, buyer_1, mockErc20, mockErc721, weth, exchange, exchangeConfig, typedDataSignatureForSeller, typedDataSignatureForBuyer } = await initiateVariables();

      await weth.connect(deployer).transfer(buyer_1.address, toWei(String("1000")));

      // Mint assets
      await mockErc721.connect(deployer).mintItem(seller_1.address, EXAMPLE_TOKEN_URI);
      await mockErc721.connect(deployer).mintItem(seller_1.address, EXAMPLE_TOKEN_URI);
      await mockErc721.connect(deployer).mintItem(seller_1.address, EXAMPLE_TOKEN_URI);
      await mockErc721.connect(deployer).mintItem(seller_1.address, EXAMPLE_TOKEN_URI);
      await mockErc721.connect(deployer).mintItem(seller_1.address, EXAMPLE_TOKEN_URI);
      await mockErc721.connect(deployer).mintItem(seller_1.address, EXAMPLE_TOKEN_URI);

      // Get owner results of minted assets
      const mintItemResults = await Promise.all([mockErc721.ownerOf(0), mockErc721.ownerOf(1), mockErc721.ownerOf(2), mockErc721.ownerOf(3), mockErc721.ownerOf(4), mockErc721.ownerOf(5)]);

      // Check owner results of minted assets
      expect(mintItemResults[0]).to.equal(seller_1.address);
      expect(mintItemResults[1]).to.equal(seller_1.address);
      expect(mintItemResults[2]).to.equal(seller_1.address);
      expect(mintItemResults[3]).to.equal(seller_1.address);
      expect(mintItemResults[4]).to.equal(seller_1.address);
      expect(mintItemResults[5]).to.equal(seller_1.address);

      // Approve tokens to exchange contract
      await Promise.all([
        mockErc721.connect(seller_1).approve(exchange.address, 0),
        mockErc721.connect(seller_1).approve(exchange.address, 1),
        mockErc721.connect(seller_1).approve(exchange.address, 2),
        mockErc721.connect(seller_1).approve(exchange.address, 3),
        mockErc721.connect(seller_1).approve(exchange.address, 4),
        mockErc721.connect(seller_1).approve(exchange.address, 5)
      ]);

      const STARTING_NONCE = 0;
      const BLOCK_TIMESTAMP = await getBlockTimestamp(ethers);
      const HOUR_IN_SECONDS = 60 * 60;

      // Get approved results of tokens to exchange contract
      const getApprovedResults = await Promise.all([mockErc721.getApproved(0), mockErc721.getApproved(1), mockErc721.getApproved(2), mockErc721.getApproved(3), mockErc721.getApproved(4), mockErc721.getApproved(5)]);

      // Check approved results which is exchange address
      expect(getApprovedResults[0]).to.equal(exchange.address);
      expect(getApprovedResults[1]).to.equal(exchange.address);
      expect(getApprovedResults[2]).to.equal(exchange.address);
      expect(getApprovedResults[3]).to.equal(exchange.address);
      expect(getApprovedResults[4]).to.equal(exchange.address);
      expect(getApprovedResults[5]).to.equal(exchange.address);

      // Send erc20 tokens with the amount of 100_000 and approve them to exchange contract
      await Promise.all([
        mockErc20.connect(deployer).transfer(buyer_1.address, MOCK_ERC20_SENT_AMOUNT),
        mockErc20.connect(buyer_1).approve(exchange.address, MOCK_ERC20_SENT_AMOUNT),
      ]);

      expect(await mockErc20.balanceOf(buyer_1.address)).to.equal(MOCK_ERC20_SENT_AMOUNT);
      expect(await mockErc20.allowance(buyer_1.address, exchange.address)).to.equal(MOCK_ERC20_SENT_AMOUNT);

      const directBuyListingWithETH: IEIP712ListingTypes = {
        originAddress: mockErc721.address,
        tokenId: 0,
        seller: seller_1.address,
        nonce: STARTING_NONCE,
        isERC20: false,
        erc20TokenAddress: ethers.constants.AddressZero,
        softCap: toWei(String(1)),
        hardCap: toWei(String(0)),
        startTimestamp: 0,
        endTimestamp: 0,
        listingType: 0,
      };

      const signatureForDirectBuyListingWithETH = await typedDataSignatureForSeller.signListingTypedData(
        directBuyListingWithETH
      );

      const englishAuctionListingWithETH: IEIP712ListingTypes = {
        originAddress: mockErc721.address,
        tokenId: 1,
        seller: seller_1.address,
        nonce: STARTING_NONCE + 1,
        isERC20: false,
        erc20TokenAddress: ethers.constants.AddressZero,
        softCap: toWei(String(1)),
        hardCap: toWei(String(2)),
        startTimestamp: BLOCK_TIMESTAMP,
        endTimestamp: BLOCK_TIMESTAMP + HOUR_IN_SECONDS,
        listingType: 1,
      };

      const englishAuctionBidWithETH: IEIP712BidTypes = {
        originAddress: mockErc721.address,
        tokenId: 1,
        bidder: buyer_1.address,
        bidAmount: toWei(String(1.5)),
        erc20TokenAddress: ethers.constants.AddressZero,
        isERC20: false,
        nonce: STARTING_NONCE,
      };

      const signatureForEnglishAuctionListingWithETH = await typedDataSignatureForSeller.signListingTypedData(
        englishAuctionListingWithETH
      );
      const signatureForEnglishAuctionBidWithETH = await typedDataSignatureForBuyer.signBidTypedData(
        englishAuctionBidWithETH
      );

      const dutchAuctionListingWithETH: IEIP712ListingTypes = {
        originAddress: mockErc721.address,
        tokenId: 2,
        seller: seller_1.address,
        nonce: STARTING_NONCE + 2,
        isERC20: false,
        erc20TokenAddress: ethers.constants.AddressZero,
        softCap: toWei(String(1)),
        hardCap: toWei(String(2)),
        startTimestamp: BLOCK_TIMESTAMP,
        endTimestamp: BLOCK_TIMESTAMP + HOUR_IN_SECONDS,
        listingType: 2,
      };

      const dutchAuctionBidWithETH: IEIP712BidTypes = {
        originAddress: mockErc721.address,
        tokenId: 2,
        bidder: buyer_1.address,
        erc20TokenAddress: ethers.constants.AddressZero,
        isERC20: false,
        bidAmount: toWei(String(1.5)),
        nonce: STARTING_NONCE + 1
      };

      const signatureForDutchAuctionListingWithETH = await typedDataSignatureForSeller.signListingTypedData(
        dutchAuctionListingWithETH
      );

      const signatureForDutchAuctionBidWithETH = await typedDataSignatureForBuyer.signBidTypedData(
        dutchAuctionBidWithETH,
      );

      const directBuyListingWithERC20: IEIP712ListingTypes = {
        originAddress: mockErc721.address,
        tokenId: 3,
        seller: seller_1.address,
        nonce: STARTING_NONCE + 3,
        isERC20: true,
        erc20TokenAddress: mockErc20.address,
        softCap: toWei(String(1)),
        hardCap: toWei(String(0)),
        startTimestamp: 0,
        endTimestamp: 0,
        listingType: 0,
      };

      const signatureForDirectBuyListingWithERC20 = await typedDataSignatureForSeller.signListingTypedData(
        directBuyListingWithERC20
      );

      const englishAuctionListingWithERC20: IEIP712ListingTypes = {
        originAddress: mockErc721.address,
        tokenId: 4,
        seller: seller_1.address,
        nonce: STARTING_NONCE + 4,
        isERC20: true,
        erc20TokenAddress: mockErc20.address,
        softCap: toWei(String(1)),
        hardCap: toWei(String(2)),
        startTimestamp: BLOCK_TIMESTAMP,
        endTimestamp: BLOCK_TIMESTAMP + HOUR_IN_SECONDS,
        listingType: 1,
      };

      const englishAuctionBidWithERC20: IEIP712BidTypes = {
        originAddress: mockErc721.address,
        tokenId: 4,
        bidder: buyer_1.address,
        erc20TokenAddress: mockErc20.address,
        isERC20: true,
        nonce: STARTING_NONCE + 2,
        bidAmount: toWei(String("1.5")),
      };

      const signatureForEnglishAuctionListingWithERC20 = await typedDataSignatureForSeller.signListingTypedData(englishAuctionListingWithERC20);
      const signatureForEnglishAuctionBidWithERC20 = await typedDataSignatureForBuyer.signBidTypedData(englishAuctionBidWithERC20);

      const dutchAuctionListingWithERC20: IEIP712ListingTypes = {
        originAddress: mockErc721.address,
        tokenId: 5,
        seller: seller_1.address,
        nonce: STARTING_NONCE + 5,
        isERC20: true,
        erc20TokenAddress: mockErc20.address,
        softCap: toWei(String(1)),
        hardCap: toWei(String(2)),
        startTimestamp: BLOCK_TIMESTAMP,
        endTimestamp: BLOCK_TIMESTAMP + HOUR_IN_SECONDS,
        listingType: 2,
      };

      const dutchAuctionBidWithERC20: IEIP712BidTypes = {
        originAddress: mockErc721.address,
        tokenId: 5,
        bidder: buyer_1.address,
        bidAmount: toWei(String("1.5")),
        erc20TokenAddress: mockErc20.address,
        isERC20: true,
        nonce: STARTING_NONCE + 3,
      };

      const signatureForDutchAuctionListingWithERC20 = await typedDataSignatureForSeller.signListingTypedData(dutchAuctionListingWithERC20);
      const signatureForDutchAuctionBidWithERC20 = await typedDataSignatureForBuyer.signBidTypedData(dutchAuctionBidWithERC20);

      // =================================================
      // DIRECT BUY WITH ETH
      // Get exchange fee
      const exchangeFeeForDirectBuyListingWithETH = await exchangeConfig.getAmountAfterFee(directBuyListingWithETH.softCap);
      // Direct buy with the address of buyer_1
      await exchange.connect(buyer_1).directBuy(directBuyListingWithETH, signatureForDirectBuyListingWithETH, 0, {
        value: exchangeFeeForDirectBuyListingWithETH[1]
      });
      // Check owner of the token with the id of 0
      expect(await mockErc721.ownerOf(directBuyListingWithETH.tokenId)).to.equal(buyer_1.address);

      // =================================================
      // ENGLISH AUCTION WITH ETH
      await incrementBlocktimestamp(ethers, HOUR_IN_SECONDS * 2);
      const exchangeFeeForEnglishAuctionListingWithETH = await exchangeConfig.getAmountAfterFee(englishAuctionBidWithETH.bidAmount);
      await weth.connect(buyer_1).approve(exchange.address, exchangeFeeForEnglishAuctionListingWithETH[1]);
      await exchange.connect(seller_1)
        .finalizeAuction(
          englishAuctionListingWithETH,
          englishAuctionBidWithETH,
          [signatureForEnglishAuctionListingWithETH, signatureForEnglishAuctionBidWithETH],
          [STARTING_NONCE + 1, STARTING_NONCE]
        );
      expect(await mockErc721.ownerOf(englishAuctionListingWithETH.tokenId)).to.equal(buyer_1.address);

      // =================================================
      // DUTH AUCTION WITH ETH
      await incrementBlocktimestamp(ethers, HOUR_IN_SECONDS * 2);
      const exchangeFeeForDutchAuctionListingWithETH = await exchangeConfig.getAmountAfterFee(dutchAuctionBidWithETH.bidAmount);
      await weth.connect(buyer_1).approve(exchange.address, exchangeFeeForDutchAuctionListingWithETH[1]);
      await exchange.connect(seller_1)
        .finalizeAuction(
          dutchAuctionListingWithETH,
          dutchAuctionBidWithETH,
          [signatureForDutchAuctionListingWithETH, signatureForDutchAuctionBidWithETH],
          [STARTING_NONCE + 2, STARTING_NONCE + 1]
        );
      expect(await mockErc721.ownerOf(dutchAuctionListingWithETH.tokenId)).to.equal(buyer_1.address);

      // =================================================
      // ENGLISH AUCTION WITH ERC20
      await incrementBlocktimestamp(ethers, HOUR_IN_SECONDS * 2);
      await mockErc20.connect(deployer).transfer(buyer_1.address, toWei(String("1000")));
      const exchangeFeeForEnglishAuctionListingWithERC20 = await exchangeConfig.getAmountAfterFee(englishAuctionBidWithERC20.bidAmount);
      await mockErc20.connect(buyer_1).approve(exchange.address, exchangeFeeForEnglishAuctionListingWithERC20[1].mul(toWei(String("2"))));
      await exchange.connect(seller_1)
        .finalizeAuction(
          englishAuctionListingWithERC20,
          englishAuctionBidWithERC20,
          [signatureForEnglishAuctionListingWithERC20, signatureForEnglishAuctionBidWithERC20],
          [STARTING_NONCE + 4, STARTING_NONCE + 2]
        );
      expect(await mockErc721.ownerOf(englishAuctionListingWithERC20.tokenId)).to.equal(buyer_1.address);

      // =================================================
      // DUTCH AUCTION WITH ERC20
      await incrementBlocktimestamp(ethers, HOUR_IN_SECONDS * 2);
      await mockErc20.connect(deployer).transfer(buyer_1.address, toWei(String("1000")));
      const exchangeFeeForDutchAuctionListingWithERC20 = await exchangeConfig.getAmountAfterFee(dutchAuctionBidWithERC20.bidAmount);
      await mockErc20.connect(buyer_1).approve(exchange.address, exchangeFeeForDutchAuctionListingWithERC20[1].mul(toWei(String("2"))));
      await exchange.connect(seller_1)
        .finalizeAuction(
          dutchAuctionListingWithERC20,
          dutchAuctionBidWithERC20,
          [signatureForDutchAuctionListingWithERC20, signatureForDutchAuctionBidWithERC20],
          [STARTING_NONCE + 5, STARTING_NONCE + 3]
        );
      expect(await mockErc721.ownerOf(dutchAuctionBidWithERC20.tokenId)).to.equal(buyer_1.address);

      // =================================================
      // DIRECT BUY WITH ERC20
      // Get exchange fee
      const exchangeFeeForDirectBuyListingWithERC20 = await exchangeConfig.getAmountAfterFee(directBuyListingWithERC20.softCap);
      // Direct buy with the address of buyer_1
      await exchange.connect(buyer_1).directBuy(directBuyListingWithERC20, signatureForDirectBuyListingWithERC20, 3, {
        value: exchangeFeeForDirectBuyListingWithERC20[1]
      });
      // Check owner of the token with the id of 3
      expect(await mockErc721.ownerOf(directBuyListingWithERC20.tokenId)).to.equal(buyer_1.address);

      const listingTuple = "tuple(address, uint256, address, uint256, uint256, uint256, uint256, bool, address, )";
    });
  });
});
