// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BuilderModifiers.sol";
import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ISimpleProvider.sol";

/// @title BuilderInternal
/// @notice This contract contains internal functions for Builders
abstract contract BuilderInternal is BuilderModifiers {
    /// @dev Concatenates an amount with additional parameters
    /// @param amount The initial amount
    /// @param params Additional parameters to concatenate
    /// @return result Concatenated array containing the amount followed by the additional parameters
    function _concatParams(uint amount, uint256[] calldata params) internal pure returns (uint256[] memory result) {
        uint256 length = params.length;
        result = new uint256[](length + 1);
        result[0] = amount;
        for (uint256 i; i < length; ) {
            result[i + 1] = params[i];
            unchecked {
                ++i;
            }
        }
    }

    /// @dev Creates a new NFT for a user pool
    /// @param provider The SimpleProvider (DealProvider, LockProvider or TimedProvider) instance
    /// @param tokenPoolId The pool ID of the token
    /// @param userData The user pool data
    /// @param params The parameters for the SimpleProvider
    /// @return amount The amount of tokens in the user pool
    function _createNewNFT(
        ISimpleProvider provider,
        uint256 tokenPoolId,
        UserPool memory userData,
        uint256[] memory params
    ) internal virtual validUserData(userData) returns (uint256 amount) {
        amount = userData.amount;
        uint256 poolId = lockDealNFT.mintForProvider(userData.user, provider);
        params[0] = userData.amount;
        provider.registerPool(poolId, params);
        lockDealNFT.cloneVaultId(poolId, tokenPoolId);
    }

    /// @dev Creates the first NFT for a SimpleProvider
    /// @param provider The SimpleProvider instance
    /// @param token The ERC20 token address
    /// @param owner The owner of the NFT
    /// @param totalAmount The total amount of tokens
    /// @param params The parameters for the SimpleProvider
    /// @param signature The cryptographic signature for the transfer
    /// @return poolId The pool ID of the created NFT
    function _createFirstNFT(
        ISimpleProvider provider,
        address token,
        address owner,
        uint256 totalAmount,
        uint256[] memory params,
        bytes calldata signature
    ) internal virtual notZeroAddress(owner) returns (uint256 poolId) {
        poolId = lockDealNFT.safeMintAndTransfer(owner, token, msg.sender, totalAmount, provider, signature);
        provider.registerPool(poolId, params);
    }
}