import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { CONTRACTS } from "../scripts/constants";
import { incrementBlocktimestamp, toWei } from "../scripts/helpers";

const MOCK_ERC721_NAME = "MockERC721";
const TOKEN_URI = "http://thisistest.uri";
const MAKER_FEE_PERCENTAGE = 5;
const TAKER_FEE_PERCENTAGE = 5;
const MAX_INT =
  "115792089237316195423570985008687907853269984665640564039457584007913129639935";

describe("Rentable", function () {
  async function initiateVariables() {
    const [deployer, fee_collector, tennant] = await ethers.getSigners();

    const RentableConfig = await ethers.getContractFactory(
      CONTRACTS.helpers.RentableConfig
    );
    const Rentable = await ethers.getContractFactory(CONTRACTS.core.Rentable);
    const MockERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721
    );
    const rentableConfig = await RentableConfig.connect(deployer).deploy(
      MAKER_FEE_PERCENTAGE,
      TAKER_FEE_PERCENTAGE
    );
    const rentable = await Rentable.connect(deployer).deploy(
      fee_collector.address,
      rentableConfig.address
    );
    const mockERC721 = await MockERC721.connect(deployer).deploy();

    return {
      deployer,
      fee_collector,
      tennant,
      rentableConfig,
      rentable,
      mockERC721,
    };
  }

  describe("Initiate", async () => {
    it("Initiate rentable contract & renting", async function () {
      const {
        deployer,
        fee_collector,
        tennant,
        rentableConfig,
        rentable,
        mockERC721,
      } = await loadFixture(initiateVariables);

      await mockERC721.connect(deployer).mintItem(deployer.address, TOKEN_URI);
      await mockERC721.connect(deployer).mintItem(deployer.address, TOKEN_URI);

      expect(await mockERC721.name()).to.equal(MOCK_ERC721_NAME);
      expect(await mockERC721.ownerOf(0)).to.equal(deployer.address);
      expect(await mockERC721.ownerOf(1)).to.equal(deployer.address);

      // Approve olmadığı için revert olması beklenir
      await expect(
        rentable.putAssetOnRent(mockERC721.address, 0, false, 0, toWei("1"))
      ).reverted;

      // 0 id'li olan ürün approve edilir
      await mockERC721.connect(deployer).approve(rentable.address, 0);

      await rentable.putAssetOnRent(
        mockERC721.address,
        0,
        false,
        0,
        toWei("1")
      );

      await rentable
        .connect(tennant)
        .lease(mockERC721.address, 0, 1, { value: toWei("1.05") });

      //   const assetInfo = await rentable.getAssetInfo(mockERC721.address, 0);

      //   console.log(assetInfo);
      //   console.log(tennant.address);

      // Blok timestamp 2 gün artır
      await incrementBlocktimestamp(ethers, 60 * 60 * 24 * 2);

      await rentable.connect(deployer).endLease(mockERC721.address, 0, { value: toWei("0.05") });

      const assetInfo = await rentable.getAssetInfo(mockERC721.address, 0);

    //   console.log(assetInfo);

      // 1 id'li olan ürün approve edilir
      await mockERC721.connect(deployer).approve(rentable.address, 1);

      await rentable.putAssetOnRent(mockERC721.address, 1, true, 1, toWei("2"));

      await rentable
        .connect(tennant)
        .lease(mockERC721.address, 1, 2, {
          value: toWei((4.2 + 1).toString()),
        });

        // Blok timestamp 2 gün artır
      await incrementBlocktimestamp(ethers, 60 * 60 * 24 * 4);

      await rentable.connect(deployer).endLease(mockERC721.address, 1, {
        value: toWei((1 + 0.2).toString()),
      });
    });
  });
});
