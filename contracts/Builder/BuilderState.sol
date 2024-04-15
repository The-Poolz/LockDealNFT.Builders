// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ILockDealNFT.sol";

/// @title BuilderState
/// @notice This contract contains state variables and events for Builders
contract BuilderState {
    /// @dev Instance of the LockDealNFT contract
    ILockDealNFT public immutable lockDealNFT;

    /// @dev Event emitted when mass pools are created
    event MassPoolsCreated(address indexed token, IProvider indexed provider, uint256 firstPoolId, uint256 userLength);

    /// @dev Error thrown when an address is zero
    error NoZeroAddress();
    /// @dev Error thrown when an invalid provider type is detected
    error InvalidProviderType();

    /// @dev Constructor initializes the contract with the provided instance of LockDealNFT
    /// @param _lockDealNFT Instance of the LockDealNFT contract
    constructor(ILockDealNFT _lockDealNFT) {
        if (address(_lockDealNFT) == address(0)) revert NoZeroAddress();
        lockDealNFT = _lockDealNFT;
    }

    /// @dev Struct to store user pool data
    struct Builder {
        UserPool[] userPools; // Array of user pools
        uint256 totalAmount; // Total amount of tokens involved
    }

    /// @dev Struct to represent a user pool
    struct UserPool {
        address user; // Address of the user
        uint256 amount; // Amount of tokens in the pool
    }
}