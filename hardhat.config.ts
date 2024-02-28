import "@nomicfoundation/hardhat-toolbox"
import "@truffle/dashboard-hardhat-plugin"
import { HardhatUserConfig } from "hardhat/config"
import "solidity-coverage"

const config: HardhatUserConfig = {
    defaultNetwork: "hardhat",
    solidity: {
        compilers: [
            {
                version: "0.8.19",
                settings: {
                    evmVersion: "istanbul",
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                },
            },
        ],
    },
    networks: {
        hardhat: {
            blockGasLimit: 130_000_000,
        },
        bscTestnet: {
            url: "https://data-seed-prebsc-1-s1.binance.org:8545",
            chainId: 97,
            //accounts: [ process.env.PRIVATE_KEY || ""],
        },
        bsc: {
            url: "https://bsc-dataseed.binance.org/",
            chainId: 56,
            //accounts: [ process.env.PRIVATE_KEY || ""],
        },
    },
}

export default config
