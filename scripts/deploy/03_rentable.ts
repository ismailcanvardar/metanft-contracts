import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";
import { toWei } from "../helpers";

const func: DeployFunction = async ({
  deployments,
  ethers,
  getChainId,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer, feeCollector } = await getNamedAccounts();

  const MAKER_FEE_PERCENTAGE = 5;
  const TAKER_FEE_PERCENTAGE = 5;

  const rentableConfig = await deploy(CONTRACTS.helpers.RentableConfig, {
    from: deployer,
    args: [MAKER_FEE_PERCENTAGE, TAKER_FEE_PERCENTAGE],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("RentableConfig contract deployed at", rentableConfig.address);

  const rentable = await deploy(CONTRACTS.core.Rentable, {
    from: deployer,
    args: [feeCollector, rentableConfig.address],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("Rentable contract deployed at", rentable.address);
};

export default func;
func.dependencies = ["RentableConfig"];
