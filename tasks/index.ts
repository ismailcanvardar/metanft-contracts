import { task } from "hardhat/config";
import fs from "fs";
import path from "path";
import { CONTRACTS } from "../scripts/constants";
import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
import prepareInstances, { IInstances } from "../scripts/prepareInstances";
import { toWei } from "../scripts/helpers";
import { Divisible__factory, MockERC721__factory } from "../typechain-types";
import util from 'util';
const exec = util.promisify(require('child_process').exec);

task(
  "flatten-contracts",
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    try {
      for (const contractSection in CONTRACTS) {
        const sectionObj = CONTRACTS[contractSection];
        const objKeys = Object.keys(sectionObj);

        for (let i = 0; i < objKeys.length; i++) {
          const contractName: string = objKeys[i];
          const contractFilePath = path.resolve(
            __dirname,
            `../contracts/${contractSection}/${contractName}.sol`
          );
          const targetFilePath = path.resolve(
            __dirname,
            `../tmp/flatteneds/flattened${contractName}.sol`
          );
          process.stdout.write(`(${contractSection} - ${i + 1}/${objKeys.length})) ${contractName} flattenning...\r`);
          await exec(`npx hardhat flatten ${contractFilePath} > ${targetFilePath}`);
        }
      }

      console.log("Task completed!");
    } catch (e) {
      console.log(e);
    }
  }
);

task(
  "extract-abis",
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    try {
      const networkName = hre.network.name;

      for (const contractSection in CONTRACTS) {
        const sectionObj = CONTRACTS[contractSection];
        const objKeys = Object.keys(sectionObj);

        for (let i = 0; i < objKeys.length; i++) {
          const innerSection = objKeys[i];
          const originFilePath = path.resolve(
            __dirname,
            `../artifacts/contracts/${contractSection}/${innerSection}.sol/${innerSection}.json`
          );
          if (!fs.existsSync(originFilePath)) {
            console.log(originFilePath, "not found!");
            break;
          }
          const abisFilePath = path.resolve(
            __dirname,
            `../tmp/abis/${networkName}/${innerSection}.json`
          );

          const abisDir = path.resolve(__dirname, `../tmp/abis`);

          const abisNetworkDir = path.resolve(
            __dirname,
            `../tmp/abis/${networkName}`
          );

          if (!fs.existsSync(abisNetworkDir)) {
            fs.mkdirSync(abisDir);
            fs.mkdirSync(abisNetworkDir);
          }

          const file = fs.readFileSync(originFilePath, "utf8");
          const abi = JSON.parse(file);
          fs.writeFileSync(abisFilePath, JSON.stringify(abi), "utf8");
        }
      }

      console.log("Task completed!");
    } catch (e) {
      console.log(e);
    }
  }
);

task(
  "extract-deployment-addresses",
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    try {
      const networkName = hre.network.name;

      const [deployer] = await hre.ethers.getSigners();

      let obj: { [key: string]: string; } = {};

      const deploymentsFolder = path.resolve(__dirname, `../tmp/deployments`);

      if (!fs.existsSync(deploymentsFolder)) {
        fs.mkdirSync(deploymentsFolder);
      }

      const deploymentsFilePath = path.resolve(
        __dirname,
        `../tmp/deployments/${networkName}.json`
      );

      if (networkName === "elanor") {
        delete CONTRACTS["mocks"]["MockERC20"];
        delete CONTRACTS["mocks"]["MockERC721"];
      }

      delete CONTRACTS["utils"]["Divisible"];
      delete CONTRACTS["utils"]["Fractional"];

      for (const contractSection in CONTRACTS) {
        const sectionObj = CONTRACTS[contractSection];
        const objKeys = Object.keys(sectionObj);

        for (let i = 0; i < objKeys.length; i++) {
          const innerSection = objKeys[i];
          const originFilePath = path.resolve(
            __dirname,
            `../deployments/${networkName}/${innerSection}.json`
          );

          if (!fs.existsSync(originFilePath)) {
            console.log(originFilePath, "not found!");
          }

          if (fs.existsSync(originFilePath)) {
            const file = fs.readFileSync(originFilePath, "utf8");
            const abi = JSON.parse(file);
            obj[innerSection] = abi.address;
          }
        }
      }

      fs.writeFileSync(deploymentsFilePath, JSON.stringify(obj), "utf8");

      console.info(
        "- Deployments on",
        networkName,
        "network were written to ./tmp/deployments/" +
        networkName +
        ".json file."
      );

      const instances: IInstances = prepareInstances(deployer, networkName);

      const dpm = instances.utils.DivisibleProxyManager;
      const fpm = instances.utils.FractionalProxyManager;

      const dpmLogic = await dpm.logic();
      const fpmLogic = await fpm.logic();

      obj["DivisibleProxyManager-Logic"] = dpmLogic;
      obj["FractionalProxyManager-Logic"] = fpmLogic;

      fs.writeFileSync(deploymentsFilePath, JSON.stringify(obj), "utf8");

      console.log("Task completed!");
    } catch (e) {
      console.log(e);
    }
  }
);

task(
  "divide",
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    const networkName = hre.network.name;
    const [deployer] = await hre.ethers.getSigners();

    const instances: IInstances = prepareInstances(deployer, networkName);

    const mintItemTx = await instances.mocks.MockERC721.mintItem(
      deployer.address,
      "http://rand.om"
    );
    const mintItem = await mintItemTx.wait();
    const event = mintItem.events?.find((event) => event.event === "Transfer");
    const [from, to, tokenId] = event?.args!;

    const approval = await instances.mocks.MockERC721.isApprovedForAll(
      deployer.address,
      instances.utils.DivisibleProxyManager.address
    );

    if (!approval) {
      await instances.mocks.MockERC721.setApprovalForAll(
        instances.utils.DivisibleProxyManager.address,
        true
      );

      console.info(
        deployer.address,
        "has approved tokens to",
        instances.mocks.MockERC721.address
      );
    }

    const DIVISIBLE_TOTAL_SUPPLY = 1_000_000;
    const DIVISIBLE_NAME = "MockDivisible" + tokenId;
    const DIVISIBLE_SYMBOL = "MD";

    await instances.utils.DivisibleProxyManager.divide(
      instances.mocks.MockERC721.address,
      tokenId,
      toWei(DIVISIBLE_TOTAL_SUPPLY.toString()),
      DIVISIBLE_NAME,
      DIVISIBLE_SYMBOL
    );
    console.info(
      "- New divisible created with the token id of",
      tokenId,
      "and origin address of",
      instances.mocks.MockERC721.address,
      "with the",
      DIVISIBLE_TOTAL_SUPPLY,
      "total supply"
    );
  }
);

task("create-presale-for-divisible", "Creates presale for divisible")
  .addOptionalParam("proxyaddress", "Divisible Proxy Address")
  .setAction(async ({ proxyaddress }, hre) => {
    const [deployer] = await hre.ethers.getSigners();
    console.log(` * network: ${hre.network.name}`);
    if (proxyaddress) {
      console.log(` * proxyaddress: ${proxyaddress}`);
    }

    const instances: IInstances = prepareInstances(deployer, hre.network.name);

    const DIVISIBLE_TOTAL_SUPPLY = 1_000_000;
    const divisible = Divisible__factory.connect(
      proxyaddress as string,
      deployer
    );
    await divisible.approve(
      proxyaddress,
      toWei(DIVISIBLE_TOTAL_SUPPLY.toString())
    );
    await divisible.startSale(toWei("1"), 10000, toWei("3000"));

    console.log(`Divisible at address ${proxyaddress} is now at presale!`);
  });

task(
  "fractionalize",
  async (taskArgs: TaskArguments, hre: HardhatRuntimeEnvironment) => {
    const networkName = hre.network.name;
    const [deployer] = await hre.ethers.getSigners();

    const instances: IInstances = prepareInstances(deployer, networkName);

    const mintItemTx = await instances.mocks.MockERC721.mintItem(
      deployer.address,
      "http://rand.om"
    );
    const mintItem = await mintItemTx.wait();
    const event = mintItem.events?.find((event) => event.event === "Transfer");
    const [from, to, tokenId] = event?.args!;

    const approval = await instances.mocks.MockERC721.isApprovedForAll(
      deployer.address,
      instances.utils.FractionalProxyManager.address
    );

    if (!approval) {
      await instances.mocks.MockERC721.setApprovalForAll(
        instances.utils.FractionalProxyManager.address,
        true
      );

      console.info(
        deployer.address,
        "has approved tokens to",
        instances.mocks.MockERC721.address
      );
    }

    const FRACTIONAL_NAME = "MockFractional" + tokenId;
    const FRACTIONAL_SYMBOL = "MF";

    await instances.utils.FractionalProxyManager.fractionalize(
      instances.mocks.MockERC721.address,
      tokenId,
      ["test", "test"],
      FRACTIONAL_NAME,
      FRACTIONAL_SYMBOL
    );
    console.info(
      "- New fractional created with the token id of",
      tokenId,
      "and origin address of",
      instances.mocks.MockERC721.address,
    );
  }
);

task("deploy-weth", "Deploys WETH contract for test purposes.")
  .setAction(async ({ proxyaddress }, hre) => {
    console.log(` * network: ${hre.network.name}`);

    const { deploy } = hre.deployments;
    const { deployer } = await hre.getNamedAccounts();

    const weth = await deploy(CONTRACTS.mocks.WETH!, {
      from: deployer,
      args: [],
      log: true,
      skipIfAlreadyDeployed: true,
    });

    console.log(`WETH contract deployed at ${weth.address}`);
  });

task("mint-mock-nft", "Mints NFT to given address from MockERC721 contract.")
  .addParam("address", "MockERC721 contract address")
  .setAction(async (taskArgs: TaskArguments, hre) => {
    console.log(` * network: ${hre.network.name}`);

    const networkName = hre.network.name;

    const [deployer] = await hre.ethers.getSigners();

    const instances: IInstances = prepareInstances(deployer, networkName);

    const mintItemTx = await instances.mocks.MockERC721.mintItem(
      deployer.address,
      "http://rand.om"
    );
    const mintItem = await mintItemTx.wait();
    const event = mintItem.events?.find((event) => event.event === "Transfer");
    const [from, to, tokenId] = event?.args!;

    console.log("MockERC721 token minted from address of",
      from, "& to address of",
      to, "& with the token id of", tokenId);
  });

task("transfer-mock-nft", "Transfers minted token to given address from given address.")
.addParam("toaddress", "MockERC721 contract address")
.addParam("id", "MockERC721 token id")
.setAction(async ({ toaddress, id }, hre) => {
    console.log(` * network: ${hre.network.name}`);

    const networkName = hre.network.name;

    const [deployer] = await hre.ethers.getSigners();

    const instances: IInstances = prepareInstances(deployer, networkName);

    const transferItemTx = await instances.mocks.MockERC721.transferFrom(
      deployer.address,
      toaddress,
      +id,
    );
    const mintItem = await transferItemTx.wait();
    const event = mintItem.events?.find((event) => event.event === "Transfer");
    const [from, to, tokenId ] = event?.args!;

    console.log("MockERC721 token transfered from address of",
      from, "& to address of",
      to, "& with the token id of", tokenId);
  });