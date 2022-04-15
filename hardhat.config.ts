import 'dotenv/config';

import { HardhatUserConfig } from "hardhat/types"
import "hardhat-deploy";

import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-etherscan';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'solidity-coverage';

import { task } from 'hardhat/config';

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task('accounts', 'Prints the list of accounts', async (taskArgs, hre) => {
    const accounts = await hre.ethers.getSigners();

    for (const account of accounts) {
        console.log(account.address);
    }
});

// https://hardhat.org/config/
const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    namedAccounts: {
        deployer: {
            default: 0,
        },
        lender: {
            default: 1,
        },
        borrower1: {
            default: 2,
        },
        borrower2: {
            default: 3,
        }
    },
    networks: {
        localhost: {
            live: false,
            saveDeployments: true,
            tags: ["local"],
        },
    },
    gasReporter: {
        enabled: process.env.REPORT_GAS !== undefined,
        currency: 'USD',
    },
    typechain: {
        outDir: 'typechain',
        target: 'ethers-v5',
    },
    solidity: {
        compilers: [
            {
                version: "0.8.9",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
};

export default config;
