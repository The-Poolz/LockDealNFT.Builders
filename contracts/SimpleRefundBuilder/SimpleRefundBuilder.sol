// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RefundBuilderInternal.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

/// @title SimpleRefundBuilder contract
/// @notice Implements a contract for building refund simple providers
contract SimpleRefundBuilder is RefundBuilderInternal, IERC721Receiver {
    using CalcUtils for uint256;

    event MassPoolsRebuilded(
        address indexed token,
        IProvider indexed provider,
        uint256 collateralPoolId,
        uint256 firstPoolId,
        uint256 userLength
    );
    error InvalidUserLength();
    error InvalidLockDealNFT();
    error InvalidCollateralProvider();
    error EmptyBytesArray();

    constructor(
        ILockDealNFT _lockDealNFT,
        IProvider _refund,
        IProvider _collateral
    ) BuilderState(_lockDealNFT) RefundBuilderState(_refund, _collateral) {}

    /// @notice ERC721 receiver function
    /// @dev This function is called when an NFT is transferred to this contract
    /// @param operator - the address that called the `safeTransferFrom` function
    /// @param user - the address that owns the NFT
    /// @param collateralPoolId - the ID of the Collateral NFT
    /// @param data - additional data with the NFT
    function onERC721Received(address operator, address user, uint256 collateralPoolId, bytes calldata data) external virtual override firewallProtected returns (bytes4) {
        if (msg.sender != address(lockDealNFT)) revert InvalidLockDealNFT();
        if (operator != address(this)) {
            if (lockDealNFT.poolIdToProvider(collateralPoolId) != collateralProvider) revert InvalidCollateralProvider();
            if (data.length == 0) revert EmptyBytesArray();
            Rebuilder memory locals;
            (
                locals.tokenSignature,
                locals.mainCoinSignature,
                locals.userData
            ) = abi.decode(data, (bytes, bytes, Builder));
            if (locals.userData.userPools.length == 0) revert InvalidUserLength();
            locals.paramsData = _getParamsData(collateralPoolId, locals.userData.totalAmount, locals.userData.userPools[0].amount);
            // one time transfer for decreasing the number of transactions
            locals.tokenPoolId = _createFirstNFT(locals, operator);
            uint256 firstPoolId = locals.tokenPoolId - 1;
            locals.paramsData.refundParams = _registerRefundProvider(firstPoolId, collateralPoolId);
            // update the collateral data and create another nft to transfer the mainСoin amount
            _updateCollateralData(locals, operator, collateralPoolId + 3);
            // create mass refund pools
            _buildMassPools(locals);
            // // transfer back the NFT to the user
            lockDealNFT.transferFrom(address(this), user, collateralPoolId);
            emit MassPoolsRebuilded(
                locals.paramsData.token,
                locals.paramsData.provider,
                collateralPoolId,
                firstPoolId,
                locals.userData.userPools.length
            );
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
        if (userData.userPools.length == 0) revert InvalidUserLength();
        locals.userData = userData;
        locals.tokenSignature = tokenSignature;
        locals.mainCoinSignature = mainCoinSignature;
        if (locals.userData.totalAmount == 0) revert NoZeroAmount();
        locals.paramsData.simpleParams = _concatParams(userData.userPools[0].amount, params[1]);
        locals.tokenPoolId = _createFirstNFT(locals);
        locals.paramsData.refundParams = _finalizeFirstNFT(locals, params[0][1]);
        _buildMassPools(locals);
        emit MassPoolsCreated(locals.paramsData.token, locals.paramsData.provider, locals.tokenPoolId - 1, userData.userPools.length);
    }
}
