// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ILockDealNFT.sol";

contract BuilderState {
    ILockDealNFT public lockDealNFT;

    struct Builder {
        UserPool[] userPools;
        uint256 totalAmount;
    }

    struct UserPool {
        address user;
        uint256 amount;
    }
}
