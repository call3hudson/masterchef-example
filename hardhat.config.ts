import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import PRIVATE_KEY from './keys';

const config: HardhatUserConfig = {
  networks: {
    rsk_testnet: {
      url: 'https://public-node.testnet.rsk.co',
      chainId: 31,
      gasPrice: 20000000000,
      accounts: [`0x${PRIVATE_KEY}`],
    },
  },
  solidity: {
    version: '0.8.19',
    settings: {
      optimizer: {
        enabled: true,
        runs: 100000,
      },
    },
  },
};

export default config;
