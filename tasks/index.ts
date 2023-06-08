import { task } from "hardhat/config";
import fs from "fs";
import path from "path";
import { CONTRACTS } from "../scripts/constants";
import { HardhatRuntimeEnvironment, TaskArguments } from "hardhat/types";
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

      if (networkName === "eleanor") {
        delete CONTRACTS["mocks"]["MockERC20"];
        delete CONTRACTS["mocks"]["MockERC721"];
      }

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

      fs.writeFileSync(deploymentsFilePath, JSON.stringify(obj), "utf8");

      console.log("Task completed!");
    } catch (e) {
      console.log(e);
    }
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