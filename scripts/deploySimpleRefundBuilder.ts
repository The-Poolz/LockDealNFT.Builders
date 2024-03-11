import { ethers } from "hardhat"

async function main() {
    const [deployer] = await ethers.getSigners()
    const lockDealNFT = "0xe42876a77108E8B3B2af53907f5e533Cba2Ce7BE"
    const collateralProvider = "0xb2b37652577A00655A45E6db8bB61251e47D4B8a"
    const refundProvider = "0xD4780f8298385a034e44515977F29E3DaC83fB0f"

    const SimpleRefundBuilder = await ethers.getContractFactory("SimpleRefundBuilder")
    const simpleRefundBuilder = await SimpleRefundBuilder.deploy(lockDealNFT, refundProvider, collateralProvider)
    await simpleRefundBuilder.deployed()

    console.log("SimpleRefundBuilder address:", simpleRefundBuilder.address)
    console.log("SimpleRefundBuilder deployed by:", deployer.address)
    console.log("SimpleRefundBuilder deployed at:", simpleRefundBuilder.deployTransaction.hash)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
