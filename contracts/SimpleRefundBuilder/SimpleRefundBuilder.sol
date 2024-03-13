// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RefundBuilderInternal.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @title SimpleRefundBuilder contract
/// @notice Implements a contract for building refund simple providers
contract SimpleRefundBuilder is RefundBuilderInternal, IERC721Receiver {
    using CalcUtils for uint256;

    constructor(ILockDealNFT _nft, IProvider _refund, IProvider _collateral) {
        lockDealNFT = _nft;
        refundProvider = _refund;
        collateralProvider = _collateral;
    }

    /// @notice ERC721 receiver function
    /// @dev This function is called when an NFT is transferred to this contract
    /// @param operator - the address that called the `safeTransferFrom` function
    /// @param user - the address that owns the NFT
    /// @param poolId - the ID of the Collateral NFT
    /// @param data - additional data with the NFT
    function onERC721Received(address operator, address user, uint256 poolId, bytes calldata data) external virtual override firewallProtected returns (bytes4) {
        require(msg.sender == address(lockDealNFT), "SimpleRefundBuilder: Only LockDealNFT contract allowed");
        if (operator != address(this)) {
            require(lockDealNFT.poolIdToProvider(poolId) == collateralProvider, "SimpleRefundBuilder: Invalid collateral provider");
            require(data.length > 0, "SimpleRefundBuilder: Invalid data length");
            Rebuilder memory locals;
            (
                locals.paramsData.simpleParams,
                locals.tokenSignature,
                locals.mainCoinSignature,
                locals.userData
            ) = abi.decode(data, (uint256[], bytes, bytes, Builder));
            require(locals.userData.userPools.length > 0, "SimpleRefundBuilder: invalid user length");
            require(locals.paramsData.simpleParams.length < 3, "SimpleRefundBuilder: Invalid SimpleProvider params length");
            locals.paramsData = _getRebuildData(poolId, locals.userData.totalAmount);
            locals.paramsData.simpleParams = _mergingParams(locals.userData.userPools[0].amount, locals.paramsData.simpleParams);
            // one time token transfer for deacrease number transactions
            locals.tokenPoolId = _createFirstNFT(locals, operator);
            locals.paramsData.refundParams = _registerRefundProvider(locals.tokenPoolId - 1, poolId);
            // update the collateral data and create another nft to transfer the mainСoin amount
            _updateCollateralData(locals, operator, poolId + 3);
            // create mass refund pools
            _userDataIterator(locals);
            // transfer back the NFT to the user
            lockDealNFT.transferFrom(address(this), user, poolId);
        }
        return this.onERC721Received.selector;
    }

    /// @param addressParams[0] = simpleProvider
    /// @param addressParams[1] = token
    /// @param addressParams[2] = mainCoin
    /// @param userData - array of user pools
    /// @param params[0] = collateral params, [0] start amount, [1] finish time
    /// @param params[1] = Array of params for simpleProvider. May be empty if this is DealProvider
    function buildMassPools(
        address[] calldata addressParams,
        Builder calldata userData,
        uint256[][] calldata params,
        bytes calldata tokenSignature,
        bytes calldata mainCoinSignature
    ) external firewallProtected {
        Rebuilder memory locals;
        locals.paramsData = _validateParamsData(addressParams, params);
        require(userData.userPools.length > 0, "SimpleRefundBuilder: invalid user length");
        locals.userData = userData;
        locals.tokenSignature = tokenSignature;
        locals.mainCoinSignature = mainCoinSignature;
        require(locals.userData.totalAmount > 0, "SimpleRefundBuilder: invalid totalAmount");
        locals.paramsData.simpleParams = _concatParams(userData.userPools[0].amount, params[1]);
        locals.tokenPoolId = _createFirstNFT(locals);
        locals.paramsData.refundParams = _finalizeFirstNFT(locals, params[0][1]);
        _userDataIterator(locals);
    }
}
