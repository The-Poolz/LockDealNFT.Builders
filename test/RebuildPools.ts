import { MockVaultManager } from "../typechain-types"
import { DealProvider } from "../typechain-types"
import { LockDealNFT } from "../typechain-types"
import { LockDealProvider } from "../typechain-types"
import { TimedDealProvider } from "../typechain-types"
import { CollateralProvider } from "../typechain-types"
import { RefundProvider } from "../typechain-types"
import { SimpleRefundBuilder } from "../typechain-types"
import { deployed, constants } from "@poolzfinance/poolz-helper-v2"
import { _createUsers, _logGasPrice } from "./helper"
import { time } from "@nomicfoundation/hardhat-network-helpers"
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers"
import { expect } from "chai"
import { BigNumber, Bytes } from "ethers"
import { ethers } from "hardhat"

describe("onERC721Received Collateral tests", function () {
    let lockProvider: LockDealProvider
    let dealProvider: DealProvider
    let mockVaultManager: MockVaultManager
    let timedProvider: TimedDealProvider
    let simpleRefundBuilder: SimpleRefundBuilder
    let lockDealNFT: LockDealNFT
    let addressParams: [string, string, string]
    let projectOwner: SignerWithAddress
    let user1: SignerWithAddress
    let user2: SignerWithAddress
    let user3: SignerWithAddress
    let startTime: BigNumber, finishTime: BigNumber
    let rebuildData: (string | number)[][]
    let totalAmount: BigNumber
    const builderType = ["bytes", "bytes", "tuple((address,uint256)[],uint256)"]
    const divideRate = ethers.utils.parseUnits("1", 21)
    const mainCoinAmount = ethers.utils.parseEther("10")
    const amount = ethers.utils.parseEther("100")
    const ONE_DAY = 86400
    const gasLimit = 130_000_000
    let packedData: string
    const tokenSignature: Bytes = ethers.utils.toUtf8Bytes("signature")
    const mainCoinsignature: Bytes = ethers.utils.toUtf8Bytes("signature")
    const token = "0xCcf41440a137299CB6af95114cb043Ce4e28679A"
    const BUSD = "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
    let refundProvider: RefundProvider
    let collateralProvider: CollateralProvider
    let collateralPoolId: number
    let refundPoolId: number

    before(async () => {
        [projectOwner, user1, user2, user3] = await ethers.getSigners()
        mockVaultManager = (await deployed("MockVaultManager")) as MockVaultManager
        lockDealNFT = (await deployed("LockDealNFT", mockVaultManager.address, "")) as LockDealNFT
        dealProvider = (await deployed("DealProvider", lockDealNFT.address)) as DealProvider
        lockProvider = (await deployed("LockDealProvider", lockDealNFT.address, dealProvider.address)) as LockDealProvider
        timedProvider = (await deployed("TimedDealProvider", lockDealNFT.address, lockProvider.address)) as TimedDealProvider
        collateralProvider = (await deployed("CollateralProvider", lockDealNFT.address, dealProvider.address)) as CollateralProvider
        refundProvider = (await deployed("RefundProvider", lockDealNFT.address, collateralProvider.address)) as RefundProvider
        simpleRefundBuilder = (await deployed("SimpleRefundBuilder", lockDealNFT.address, refundProvider.address, collateralProvider.address)) as SimpleRefundBuilder
        await Promise.all([
            lockDealNFT.setApprovedContract(refundProvider.address, true),
            lockDealNFT.setApprovedContract(lockProvider.address, true),
            lockDealNFT.setApprovedContract(dealProvider.address, true),
            lockDealNFT.setApprovedContract(timedProvider.address, true),
            lockDealNFT.setApprovedContract(collateralProvider.address, true),
            lockDealNFT.setApprovedContract(lockDealNFT.address, true),
            lockDealNFT.setApprovedContract(simpleRefundBuilder.address, true),
        ])
        rebuildData = [
            [user1.address, amount.toString()],
            [user2.address, amount.mul(2).toString()],
            [user3.address, amount.mul(3).toString()],
        ]
        totalAmount = amount.mul(6)
    })

    beforeEach(async () => {
        addressParams = [lockProvider.address, token, BUSD]
        startTime = ethers.BigNumber.from((await time.latest()) + ONE_DAY) // plus 1 day
        finishTime = startTime.add(7 * ONE_DAY) // plus 7 days from `startTime`
        const userCount = "10"
        const userPools = _createUsers(amount.toString(), userCount)
        const params = _createProviderParams(lockProvider.address)
        packedData = ethers.utils.defaultAbiCoder.encode(builderType, [
            tokenSignature,
            mainCoinsignature,
            [rebuildData, totalAmount],
        ])
        collateralPoolId = (await lockDealNFT.totalSupply()).toNumber() + 2
        await simpleRefundBuilder.buildMassPools(addressParams, userPools, params, tokenSignature, mainCoinsignature, {
            gasLimit,
        })
        refundPoolId = (await lockDealNFT.totalSupply()).toNumber()
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
        await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
            projectOwner.address,
            simpleRefundBuilder.address,
            collateralPoolId,
            packedData
        )
        expect(owner).to.equal(projectOwner.address)
    })

    it("should update collateral data", async () => {
        const mainCoinAmount = (await lockDealNFT.getData(collateralPoolId + 3)).params[0]
        await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
            projectOwner.address,
            simpleRefundBuilder.address,
            collateralPoolId,
            packedData
        )
        const rate = await collateralProvider.poolIdToRateToWei(collateralPoolId)
        expect((await lockDealNFT.getData(collateralPoolId + 3)).params[0]).to.equal(
            mainCoinAmount.add(totalAmount.mul(rate).div(divideRate))
        )
    })

    it("should set collateral pool id to new refunds", async () => {
        await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
            projectOwner.address,
            simpleRefundBuilder.address,
            collateralPoolId,
            packedData
        )
        expect(await refundProvider.poolIdToCollateralId(refundPoolId)).to.equal(collateralPoolId)
        expect(await refundProvider.poolIdToCollateralId(refundPoolId + 3)).to.equal(collateralPoolId)
        expect(await refundProvider.poolIdToCollateralId(refundPoolId + 5)).to.equal(collateralPoolId)
    })

    it("should create nft for main coin transfer", async () => {
        await lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
            projectOwner.address,
            simpleRefundBuilder.address,
            collateralPoolId,
            packedData
        )
        const nftId = refundPoolId + 2
        expect(await lockDealNFT.ownerOf(nftId)).to.equal(simpleRefundBuilder.address)
    })

    it("should revert invalid nft token", async () => {
        // fake nft token
        const newlockDealNFT = (await deployed("LockDealNFT", mockVaultManager.address, "")) as LockDealNFT
        const dealProvider = (await deployed("DealProvider", newlockDealNFT.address)) as DealProvider
        await newlockDealNFT.setApprovedContract(dealProvider.address, true)
        await newlockDealNFT.setApprovedContract(simpleRefundBuilder.address, true)
        await dealProvider.createNewPool([projectOwner.address, token], [amount], tokenSignature)
        // send fake nft token to simple refund builder
        await expect(
            newlockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
                projectOwner.address,
                simpleRefundBuilder.address,
                0,
                packedData
            )
        ).to.be.revertedWith("SimpleRefundBuilder: Only LockDealNFT contract allowed")
    })

    it("should revert empty data", async () => {
        await expect(
            lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
                projectOwner.address,
                simpleRefundBuilder.address,
                collateralPoolId,
                []
            )
        ).to.be.revertedWith("SimpleRefundBuilder: Invalid data length")
    })

    it("should revert ivalid collateral pool id", async () => {
        await dealProvider.createNewPool([projectOwner.address, token], [amount], tokenSignature)
        await expect(
            lockDealNFT["safeTransferFrom(address,address,uint256,bytes)"](
                projectOwner.address,
                simpleRefundBuilder.address,
                (await lockDealNFT.totalSupply()).sub(1),
                packedData
            )
        ).to.be.revertedWith("SimpleRefundBuilder: Invalid collateral provider")
    })

    it("should revert transfer not from owner", async () => {
        await expect(
            lockDealNFT
                .connect(user1)["safeTransferFrom(address,address,uint256,bytes)"](projectOwner.address, simpleRefundBuilder.address, collateralPoolId, packedData)
        ).to.be.revertedWith("ERC721: caller is not token owner or approved")
    })
    
    it("should revert zero lockDealNFT address", async () => {
        const simpleRefundBuilder = await ethers.getContractFactory("SimpleRefundBuilder")
        await expect(simpleRefundBuilder.deploy(ethers.constants.AddressZero, refundProvider.address, collateralProvider.address)
        ).to.be.revertedWith("BuilderState: lockDealNFT zero address")
    })

    it("should revert zero RefundProvider address", async () => {
        const simpleRefundBuilder = await ethers.getContractFactory("SimpleRefundBuilder")
        await expect(simpleRefundBuilder.deploy(lockDealNFT.address, ethers.constants.AddressZero, collateralProvider.address)
        ).to.be.revertedWith("SimpleRefundBuilder: RefundProvider zero address")
    })

    it("should revert zero CollateralProvider address", async () => {
        const simpleRefundBuilder = await ethers.getContractFactory("SimpleRefundBuilder")
        await expect(simpleRefundBuilder.deploy(lockDealNFT.address, refundProvider.address, ethers.constants.AddressZero)
        ).to.be.revertedWith("SimpleRefundBuilder: CollateralProvider zero address")
    })
})
