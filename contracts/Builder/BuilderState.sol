// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ILockDealNFT.sol";

contract BuilderState {
    ILockDealNFT public immutable lockDealNFT;

    event MassPoolsCreated(address indexed token, IProvider indexed provider, uint256 firstPoolId, uint256 userLength);

    constructor(ILockDealNFT _lockDealNFT) {
        require(address(_lockDealNFT) != address(0), "BuilderState: lockDealNFT zero address");
        lockDealNFT = _lockDealNFT;
    }

    struct Builder {
        UserPool[] userPools;
        uint256 totalAmount;
    }

    struct UserPool {
        address user;
        uint256 amount;
    }
}
