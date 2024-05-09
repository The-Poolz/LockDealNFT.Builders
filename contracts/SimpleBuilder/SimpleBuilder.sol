// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "../Builder/BuilderInternal.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";

/// @title SimpleBuilder contract
/// @notice This contract is used to create mass lock deals(NFTs)
contract SimpleBuilder is ERC721Holder, BuilderInternal, FirewallConsumer {
    /// @dev Constructor to initialize the SimpleBuilder contract with the provided instance of LockDealNFT
    /// @param _lockDealNFT Instance of the LockDealNFT contract
    constructor(ILockDealNFT _lockDealNFT) BuilderState(_lockDealNFT) {}

    /// @dev Error thrown when an invalid user length is detected
    error InvalidUserLength();

    /// @dev Struct to store local variables for building mass pools
    struct MassPoolsLocals {
        uint256 totalAmount;
        address token;
        ISimpleProvider provider;
        uint256 length;
        uint256 poolId;
    }

    /// @notice Build mass pools
    /// @param addressParams[0] - Provider address
    /// @param addressParams[1] - Token address
    /// @param userData Array of user pools containing user addresses and corresponding token amounts
    /// @param params Array of parameters (may be empty if this is a DealProvider)
    /// @param signature Cryptographic signature for the transfer
    /// @param data Additional data for the firewall
    function buildMassPools(
        address[] calldata addressParams,
        Builder calldata userData,
        uint256[] calldata params,
        bytes calldata signature,
        bytes memory data
    ) external firewallProtectedCustom(data) {
        _notZeroAddress(addressParams[1]);
        _validParamsLength(addressParams.length, 2);
        if (!ERC165Checker.supportsInterface(addressParams[0], type(ISimpleProvider).interfaceId)) {
            revert InvalidProviderType();
        }
        if (userData.userPools.length == 0) revert InvalidUserLength();
        MassPoolsLocals memory locals;
        locals.totalAmount = userData.totalAmount;
        _notZeroAmount(locals.totalAmount);
        locals.token = addressParams[1];
        locals.provider = ISimpleProvider(addressParams[0]);
        UserPool calldata firstUserData = userData.userPools[0];
        locals.length = userData.userPools.length;
        // one time transfer for decreasing the number of transactions
        uint256[] memory simpleParams = _concatParams(firstUserData.amount, params);
        locals.poolId = _createFirstNFT(locals.provider, locals.token, firstUserData.user, locals.totalAmount, simpleParams, signature);
        locals.totalAmount -= firstUserData.amount;
        for (uint256 i = 1; i < locals.length; ) {
            UserPool calldata userPool = userData.userPools[i];
            locals.totalAmount -= _createNewNFT(locals.provider, locals.poolId, userPool, simpleParams);
            unchecked {
                ++i;
            }
        }
        assert(locals.totalAmount == 0);
        emit MassPoolsCreated(locals.token, locals.provider, locals.poolId, userData.userPools.length);
    }
}