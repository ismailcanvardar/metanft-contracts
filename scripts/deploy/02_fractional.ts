import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONTRACTS } from "../constants";

const func: DeployFunction = async ({
  deployments,
  ethers,
  getChainId,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  const fractionalProxyManager = await deploy(CONTRACTS.utils.FractionalProxyManager, {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("FractionalProxyManager contract deployed at", fractionalProxyManager.address);
};

export default func;
