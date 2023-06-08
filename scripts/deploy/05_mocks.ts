import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CHAIN_IDS, CONTRACTS } from "../constants";
import { toWei } from "../helpers";

const func: DeployFunction = async ({
  deployments,
  ethers,
  getChainId,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const chainId = await getChainId();

  const MOCKERC20_INITIAL_SUPPLY = 1_000_000_000;

  if (chainId !== String(CHAIN_IDS.ELANOR)) {
    if (CONTRACTS.mocks.MockERC20 && CONTRACTS.mocks.MockERC721) {
      const mockERC20 = await deploy(CONTRACTS.mocks.MockERC20, {
        from: deployer,
        args: [toWei((MOCKERC20_INITIAL_SUPPLY).toString())],
        log: true,
        skipIfAlreadyDeployed: true,
      });

      console.log("MockERC20 contract deployed at", mockERC20.address);

      const mockERC721 = await deploy(CONTRACTS.mocks.MockERC721, {
        from: deployer,
        args: [],
        log: true,
        skipIfAlreadyDeployed: true,
      });

      console.log("MockERC721 contract deployed at", mockERC721.address);
    }
  }
};

export default func;
