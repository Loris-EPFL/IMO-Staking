import { HardhatUserConfig } from "hardhat/types";

import "@nomiclabs/hardhat-waffle";
import "@typechain/hardhat";
import "hardhat-contract-sizer";
import "@nomiclabs/hardhat-etherscan";
import "solidity-coverage";
import "hardhat-gas-reporter"

require("dotenv").config();


const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  solidity: {
    compilers: [
      {
        version: "0.8.10",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200
          },
        }
      }
    ],
    overrides: {
      'contracts/test/PaladinToken.sol': {
        version: "0.8.4",
        settings: {
          optimizer: {
            enabled: true,
            runs: 999999 //keeping that score since it's the one used for live version
          },
        }
      },
    }
  },
  contractSizer: {
    alphaSort: true,
    runOnCompile: true,
    disambiguatePaths: false,
  },
  networks: {
    hardhat: {
      forking: {
        url: "https://eth-mainnet.alchemyapi.io/v2/" + (process.env.ALCHEMY_API_KEY || ''),
        blockNumber: 13178506
      },
      allowUnlimitedContractSize: true,
    },
    mainnet: {
      url: process.env.MAINNET_URI,
      accounts: [process.env.MAINNET_PRIVATE_KEY || ''],
      /*accounts: {
        mnemonic: process.env.MAINNET_MNEMONIC,
      },*/
    }
   
  },
  typechain: {
    outDir: "typechain",
    target: "ethers-v5"
  },
  gasReporter: {
    enabled: true
  }
};

export default config;
