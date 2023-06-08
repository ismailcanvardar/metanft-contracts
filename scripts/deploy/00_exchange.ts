import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { CONSTRUCTOR_PARAMS, CONTRACTS } from "../constants";

const func: DeployFunction = async ({
  deployments,
  ethers,
  getChainId,
  getNamedAccounts,
}: HardhatRuntimeEnvironment) => {
  const { deploy } = deployments;
  const { deployer, feeCollector } = await getNamedAccounts();

  const exchangeConfig = await deploy(CONTRACTS.helpers.ExchangeConfig, {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("ExchangeConfig contract deployed at", exchangeConfig.address);

  const affiliate = await deploy(CONTRACTS.utils.Affiliate, {
    from: deployer,
    args: [],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("Affiliate contract deployed at", affiliate.address);

  const royaltyFeeManager = await deploy(CONTRACTS.helpers.RoyaltyFeeManager, {
    from: deployer,
    args: [CONSTRUCTOR_PARAMS.RoyaltyFeeManager.MAXIMUM_FEE_PERCENTAGE],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("royaltyFeeManager contract deployed at", royaltyFeeManager.address);

  const exchange = await deploy(CONTRACTS.core.Exchange, {
    from: deployer,
    args: [feeCollector, affiliate.address, exchangeConfig.address, royaltyFeeManager.address, CONSTRUCTOR_PARAMS.Exchange.WETH],
    log: true,
    skipIfAlreadyDeployed: true,
  });

  console.log("Exchange contract deployed at", exchange.address);
};

export default func;

func.dependencies = ["FeeCollector", "Affiliate", "ExchangeConfig", "RoyaltyFeeManager", "WETH"];
