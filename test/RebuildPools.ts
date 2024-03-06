import { MockVaultManager } from "../typechain-types"
import { DealProvider } from "../typechain-types"
import { LockDealNFT } from "../typechain-types"
import { LockDealProvider } from "../typechain-types"
import { TimedDealProvider } from "../typechain-types"
import { CollateralProvider } from "../typechain-types"
import { RefundProvider } from "../typechain-types"
import { SimpleRefundBuilder } from "../typechain-types"
import { deployed } from "@poolzfinance/poolz-helper-v2"
import { _createUsers, _logGasPrice } from "./helper"
import { time } from "@nomicfoundation/hardhat-network-helpers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import { BigNumber, Bytes } from "ethers"
import { BuilderState } from "../typechain-types/contracts/SimpleBuilder/SimpleBuilder"
import { ethers } from "hardhat"

describe("onERC721Received Collateral tests", function () {
    let lockProvider: LockDealProvider
    let dealProvider: DealProvider
    let mockVaultManager: MockVaultManager
    let timedProvider: TimedDealProvider
    let simpleRefundBuilder: SimpleRefundBuilder
    let lockDealNFT: LockDealNFT
    let userData: BuilderState.BuilderStruct
    let addressParams: [string, string, string]
    let projectOwner: SignerWithAddress
    let user1: SignerWithAddress
    let user2: SignerWithAddress
    let user3: SignerWithAddress
    let startTime: BigNumber, finishTime: BigNumber
    const mainCoinAmount = ethers.utils.parseEther("10")
    const amount = ethers.utils.parseEther("100").toString()
    const ONE_DAY = 86400
    const gasLimit = 130_000_000
    let packedData: string
    const tokenSignature: Bytes = ethers.utils.toUtf8Bytes("signature")
    const mainCoinsignature: Bytes = ethers.utils.toUtf8Bytes("signature")
    const token = "0xCcf41440a137299CB6af95114cb043Ce4e28679A"
    const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
    let refundProvider: RefundProvider
    let collateralProvider: CollateralProvider
    let vaultId: number
    let collateralPoolId: number

    before(async () => {
        [projectOwner, user1, user2, user3] = await ethers.getSigners()
        mockVaultManager = (await deployed("MockVaultManager")) as MockVaultManager
        lockDealNFT = (await deployed("LockDealNFT", mockVaultManager.address, "")) as LockDealNFT
        dealProvider = (await deployed("DealProvider", lockDealNFT.address)) as DealProvider
        lockProvider = (await deployed("LockDealProvider", lockDealNFT.address, dealProvider.address)) as LockDealProvider
        timedProvider = (await deployed("TimedDealProvider", lockDealNFT.address, lockProvider.address)) as TimedDealProvider
        collateralProvider = (await deployed("CollateralProvider", lockDealNFT.address, dealProvider.address)) as CollateralProvider
        refundProvider = (await deployed("RefundProvider", lockDealNFT.address, collateralProvider.address)) as RefundProvider
        simpleRefundBuilder = (await deployed(
            "SimpleRefundBuilder",
            lockDealNFT.address,
            refundProvider.address,
            collateralProvider.address
        )) as SimpleRefundBuilder
        await Promise.all([
            lockDealNFT.setApprovedContract(refundProvider.address, true),
            lockDealNFT.setApprovedContract(lockProvider.address, true),
            lockDealNFT.setApprovedContract(dealProvider.address, true),
            lockDealNFT.setApprovedContract(timedProvider.address, true),
            lockDealNFT.setApprovedContract(collateralProvider.address, true),
            lockDealNFT.setApprovedContract(lockDealNFT.address, true),
            lockDealNFT.setApprovedContract(simpleRefundBuilder.address, true),
        ])
    })

    beforeEach(async () => {
        vaultId = (await mockVaultManager.Id()).toNumber()
        addressParams = [dealProvider.address, token, BUSD]
        startTime = ethers.BigNumber.from((await time.latest()) + ONE_DAY) // plus 1 day
        finishTime = startTime.add(7 * ONE_DAY) // plus 7 days from `startTime`
        const userCount = "10"
        const userPools = _createUsers(amount, userCount)
        const totalAmount = 600; // Example total amount
        const builderType = ["uint256[]","bytes","bytes","tuple((address,uint256)[],uint256)"];
        const params = _createProviderParams(dealProvider.address)
        packedData = ethers.utils.defaultAbiCoder.encode(
            builderType,
            [
                [],
                tokenSignature,
                mainCoinsignature,
                [[[user1.address, 100], [user2.address, 200], [user3.address, 300]], totalAmount]
            ]
        )
        collateralPoolId = (await lockDealNFT.totalSupply()).toNumber() + 2
        await simpleRefundBuilder
            .connect(projectOwner)
            .buildMassPools(addressParams, userPools, params, tokenSignature, mainCoinsignature, { gasLimit })
    })

    function _createProviderParams(provider: string): string[][] {
        addressParams[0] = provider
        return provider == dealProvider.address
            ? [[mainCoinAmount.toString(), finishTime.toString()], []]
            : provider == lockProvider.address
              ? [[mainCoinAmount.toString(), finishTime.toString()], [finishTime.toString()]]
              : [
                    [mainCoinAmount.toString(), finishTime.toString()],
                    [startTime.toString(), finishTime.toString()],
                ]
    }

    it("should return Collateral NFT deposit after rebuilding", async () => {
        const owner = await lockDealNFT.ownerOf(collateralPoolId)
        await lockDealNFT
            .connect(projectOwner)["safeTransferFrom(address,address,uint256,bytes)"](projectOwner.address, simpleRefundBuilder.address, collateralPoolId, packedData)
        expect(owner).to.equal(projectOwner.address)
    })

    it("should send two arrays", async () => {})
})
