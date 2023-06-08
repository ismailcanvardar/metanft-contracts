import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expect } from "chai";
import { ethers } from "hardhat";
import { CONTRACTS } from "../scripts/constants";

const TOKEN_URI = "http://thisistest.uri";
const TOKEN_URIS = Array(3).fill(TOKEN_URI);
const FRACTIONAL_NAME = "Fractional";
const FRACTIONAL_SYMBOL = "FSYMB";

describe("Fractional", function () {
  async function initiateVariables() {
    // Contracts are deployed using the first signer/account by default
    const [deployer] = await ethers.getSigners();

    const Fractional = await ethers.getContractFactory(
      CONTRACTS.utils.Fractional
    );
    const MockERC721 = await ethers.getContractFactory(
      CONTRACTS.mocks.MockERC721
    );
    const fractional = await Fractional.connect(deployer).deploy();
    const mockERC721 = await MockERC721.connect(deployer).deploy();

    return { deployer, fractional, mockERC721 };
  }

  describe("Deployment", async () => {
    it("Should call initialize function", async () => {
      const { deployer, fractional, mockERC721 } = await loadFixture(initiateVariables);

      await mockERC721.mintItem(deployer.address, TOKEN_URI);

      expect(await mockERC721.ownerOf(0)).to.equal(deployer.address);

      await mockERC721.connect(deployer).transferFrom(deployer.address, fractional.address, 0);

      await fractional.initialize(
        deployer.address,
        mockERC721.address,
        0,
        TOKEN_URIS,
        FRACTIONAL_NAME,
        FRACTIONAL_SYMBOL
      );

      await fractional.connect(deployer).reclaim();
    });
  });
});
