import { BigNumber, ethers } from "ethers";
import { HardhatEthersHelpers } from "hardhat/types";
import { IBid, IListing } from "./signature-helper";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

const createListingTuple = (listing: IListing): any[] => {
  const {
    originAddress,
    tokenId,
    seller,
    startTimestamp,
    endTimestamp,
    softCap,
    hardCap,
    isERC20,
    erc20TokenAddress,
    listingType,
  } = listing;
  return [
    originAddress,
    tokenId,
    seller,
    startTimestamp,
    endTimestamp,
    softCap,
    hardCap,
    isERC20,
    erc20TokenAddress,
    listingType,
  ];
};

const createBidTuple = (bid: IBid): any[] => {
  const {
    originAddress,
    tokenId,
    bidder,
    bidAmount,
    isERC20,
    erc20TokenAddress,
  } = bid;
  return [
    originAddress,
    tokenId,
    bidder,
    bidAmount,
    isERC20,
    erc20TokenAddress,
  ];
};

const getBlockTimestamp = async (
  ethers: HardhatEthersHelpers
): Promise<number> => {
  const blockNumBefore = await ethers.provider.getBlockNumber();
  const blockBefore = await ethers.provider.getBlock(blockNumBefore);
  return blockBefore.timestamp;
};

const toWei = (amount: string): ethers.BigNumber => {
  return ethers.utils.parseEther(amount);
};

const callMethod = async (
  contract: ethers.Contract,
  signer: SignerWithAddress,
  methodName: string,
  params: any[],
  value?: BigNumber
): Promise<any> => {
  if (value) {
    params.push({ value });
  }

  return await contract.connect(signer)[methodName].apply(null, params);
};

const incrementBlocktimestamp = async (
  ethers: HardhatEthersHelpers,
  givenTimeAmount: number
) : Promise<void> => {
  await ethers.provider.send("evm_increaseTime", [givenTimeAmount]);
  await ethers.provider.send("evm_mine", []);
};

const calculateExchangeFee = (amount: number, percentage: number) => {
  return (amount * percentage) / 100;
};

export {
  createBidTuple,
  createListingTuple,
  getBlockTimestamp,
  toWei,
  callMethod,
  calculateExchangeFee,
  incrementBlocktimestamp,
};
