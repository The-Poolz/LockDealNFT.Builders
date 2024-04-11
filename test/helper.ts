import { BuilderState } from '../typechain-types/contracts/Builders/SimpleBuilder/SimpleBuilder';
import { ContractReceipt } from 'ethers';
import { ethers } from 'hardhat';

export function _createUsers(amount: string, userCount: string): BuilderState.BuilderStruct {
    const pools = [];
    const length = parseInt(userCount);
    // Create signers
    for (let i = 0; i < length; ++i) {
      const privateKey = ethers.Wallet.createRandom().privateKey;
      const signer = new ethers.Wallet(privateKey);
      const user = signer.address;
      pools.push({ user: user, amount: amount });
    }
    const totalAmount = ethers.BigNumber.from(amount).mul(length);
    return { userPools: pools, totalAmount: totalAmount };
  }
  
  export function _logGasPrice(txReceipt: ContractReceipt, userLength: number) {
    const gasUsed = txReceipt.gasUsed;
    const GREEN_TEXT = '\x1b[32m';
    console.log(`${GREEN_TEXT}Gas Used: ${gasUsed.toString()}`);
    console.log(`Price per one pool: ${gasUsed.div(userLength)}`);
  }

export const deployed = async <T>(contractName: string, ...args: string[]): Promise<T> => {
    const Contract = await ethers.getContractFactory(contractName);
    const contract = await Contract.deploy(...args, { gasLimit: 130_000_000 });
    return contract.deployed() as Promise<T>;
};