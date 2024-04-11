import { MockVaultManager } from '../typechain-types';
import { DealProvider } from '../typechain-types';
import { LockDealProvider } from '../typechain-types';
import { TimedDealProvider } from '../typechain-types';
import { SimpleBuilder } from '../typechain-types';
import { _createUsers, _logGasPrice, deployed } from './helper';
import LockDealNFTArtifact from "@poolzfinance/lockdeal-nft/artifacts/contracts/LockDealNFT/LockDealNFT.sol/LockDealNFT.json"
import { time } from '@nomicfoundation/hardhat-network-helpers';
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers';
import { expect } from 'chai';
import { BigNumber, Bytes } from 'ethers';
import { ethers } from 'hardhat';
import { BuilderState } from '../typechain-types/contracts/Builders/SimpleBuilder/SimpleBuilder';
import { Contract } from "hardhat/internal/hardhat-network/stack-traces/model"

describe('Simple Builder tests', function () {
  let lockProvider: LockDealProvider;
  let dealProvider: DealProvider;
  let mockVaultManager: MockVaultManager;
  let timedProvider: TimedDealProvider;
  let simpleBuilder: SimpleBuilder;
  let lockDealNFT: Contract;
  let userData: BuilderState.BuilderStruct;
  let addressParams: [string, string];
  let projectOwner: SignerWithAddress;
  let startTime: BigNumber, finishTime: BigNumber;
  const token = "0xCcf41440a137299CB6af95114cb043Ce4e28679A"
  const signature: Bytes = ethers.utils.toUtf8Bytes('signature');
  const amount = ethers.utils.parseEther('100').toString();
  const ONE_DAY = 86400;

  async function _testMassPoolsData(provider: string, amount: string, userCount: string, params: BigNumber[]) {
    userData = _createUsers(amount, userCount);
    const lastPoolId = (await lockDealNFT.totalSupply()).toNumber();
    const tx = await simpleBuilder.connect(projectOwner).buildMassPools(addressParams, userData, params, signature);
    const txReceipt = await tx.wait();
    _logGasPrice(txReceipt, userData.userPools.length);
    params.splice(0, 0, ethers.BigNumber.from(amount));
    if (provider == timedProvider.address) {
      params.push(ethers.BigNumber.from(amount));
    }
    
    const poolIds : number[] = []
    for (let i = lastPoolId; i < userData.userPools.length + lastPoolId; i+=2) {
      poolIds.push(i)
    }
    
    const allData = poolIds.map( (i) => (lockDealNFT.getData(i)))
    const allDataResults = await Promise.all(allData)
    let k = 0;
    for (const [index, data] of allDataResults.entries()) {
      expect(data.provider).to.equal(provider);
      expect(data.poolId).to.equal(poolIds[index]);
      expect(data.owner).to.equal(userData.userPools[k].user);
      expect(data.token).to.equal(token);
      expect(data.params).to.deep.equal(params);
      k+=2;
    }
  }

  function _createProviderParams(provider: string) {
    addressParams[0] = provider;
    return provider == dealProvider.address
      ? []
      : provider == lockProvider.address
      ? [finishTime]
      : [startTime, finishTime];
  }

  before(async () => {
    [projectOwner] = await ethers.getSigners();
    mockVaultManager = await deployed('MockVaultManager');
    const baseURI = 'https://nft.poolz.finance/test/metadata/';
    const LockDealNFT = await ethers.getContractFactory(LockDealNFTArtifact.abi, LockDealNFTArtifact.bytecode)
    lockDealNFT = await LockDealNFT.deploy(mockVaultManager.address, baseURI)
    await lockDealNFT.deployed()
    dealProvider = await deployed('DealProvider', lockDealNFT.address);
    lockProvider = await deployed('LockDealProvider', lockDealNFT.address, dealProvider.address);
    timedProvider = await deployed('TimedDealProvider', lockDealNFT.address, lockProvider.address);
    simpleBuilder = await deployed('SimpleBuilder', lockDealNFT.address);
    await lockDealNFT.setApprovedContract(lockProvider.address, true);
    await lockDealNFT.setApprovedContract(dealProvider.address, true);
    await lockDealNFT.setApprovedContract(timedProvider.address, true);
    await lockDealNFT.setApprovedContract(lockDealNFT.address, true);
    await lockDealNFT.setApprovedContract(simpleBuilder.address, true);
  });

  beforeEach(async () => {
    userData = await _createUsers(amount, '4');
    addressParams = [timedProvider.address, token];
    startTime = ethers.BigNumber.from((await time.latest()) + ONE_DAY); // plus 1 day
    finishTime = startTime.add(7 * ONE_DAY); // plus 7 days from `startTime`
  });

  it('should create 10 dealProvider pools', async () => {
    const userCount = '10';
    const params = _createProviderParams(dealProvider.address);
    await _testMassPoolsData(dealProvider.address, amount, userCount, params);
  });

  it('should create 50 dealProvider pools', async () => {
    const userCount = '50';
    const params = _createProviderParams(dealProvider.address);
    await _testMassPoolsData(dealProvider.address, amount, userCount, params);
  });

  it('should create 100 dealProvider pools', async () => {
    const userCount = '100';
    const params = _createProviderParams(dealProvider.address);
    await _testMassPoolsData(dealProvider.address, amount, userCount, params);
  });

  it('should create 10 lockProvider pools', async () => {
    const userCount = '10';
    const params = _createProviderParams(lockProvider.address);
    await _testMassPoolsData(lockProvider.address, amount, userCount, params);
  });

  it('should create 50 lockProvider pools', async () => {
    const userCount = '50';
    const params = _createProviderParams(lockProvider.address);
    await _testMassPoolsData(lockProvider.address, amount, userCount, params);
  });

  it('should create 100 lockProvider pools', async () => {
    const userCount = '100';
    const params = _createProviderParams(lockProvider.address);
    await _testMassPoolsData(lockProvider.address, amount, userCount, params);
  });

  it('should create 10 timedProvider pools', async () => {
    const userCount = '10';
    const params = _createProviderParams(timedProvider.address);
    await _testMassPoolsData(timedProvider.address, amount, userCount, params);
  });

  it('should create 50 timedProvider pools', async () => {
    const userCount = '50';
    const params = _createProviderParams(timedProvider.address);
    await _testMassPoolsData(timedProvider.address, amount, userCount, params);
  });

  it('should create 100 timedProvider pools', async () => {
    const userCount = '100';
    const params = _createProviderParams(timedProvider.address);
    await _testMassPoolsData(timedProvider.address, amount, userCount, params);
  });
});
