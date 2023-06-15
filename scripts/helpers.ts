import { BigNumber, ethers } from "ethers";
import { HardhatEthersHelpers } from "hardhat/types";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

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
  getBlockTimestamp,
  toWei,
  callMethod,
  calculateExchangeFee,
  incrementBlocktimestamp,
};
