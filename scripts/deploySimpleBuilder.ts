import { ethers } from "hardhat"

async function main() {
    const [deployer] = await ethers.getSigners()
    const lockDealNFT = "0xe42876a77108E8B3B2af53907f5e533Cba2Ce7BE"

    const SimpleBuilder = await ethers.getContractFactory("SimpleBuilder")
    const simpleBuilder = await SimpleBuilder.deploy(lockDealNFT)
    await simpleBuilder.deployed()

    console.log("SimpleBuilder address:", simpleBuilder.address)
    console.log("SimpleBuilder deployed by:", deployer.address)
    console.log("SimpleBuilder deployed at:", simpleBuilder.deployTransaction.hash)
}

main().catch((error) => {
    console.error(error)
    process.exitCode = 1
})
