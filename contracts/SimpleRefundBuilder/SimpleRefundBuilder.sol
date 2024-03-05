// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RefundBuilderInternal.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "hardhat/console.sol";

/// @title SimpleRefundBuilder contract
/// @notice Implements a contract for building refund simple providers
contract SimpleRefundBuilder is RefundBuilderInternal, IERC721Receiver {
    using CalcUtils for uint256;

    constructor(ILockDealNFT _nft, IProvider _refund, IProvider _collateral) {
        lockDealNFT = _nft;
        refundProvider = _refund;
        collateralProvider = _collateral;
    }

    struct Rebuilder {
        ISimpleProvider provider;
        uint256[] params;
        bytes tokenSignature;
        bytes mainCoinSignature;
        Builder userData;
        uint256 refundPoolId;
        address token;
        address mainCoin;
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
                locals.params,
                locals.tokenSignature,
                locals.mainCoinSignature,
                locals.userData
            ) = abi.decode(data, (uint256[], bytes, bytes, Builder));
            require(locals.userData.userPools.length > 0, "SimpleRefundBuilder: invalid user length");
            require(locals.params.length < 3, "SimpleRefundBuilder: Invalid SimpleProvider params length");

            locals.refundPoolId = poolId - 2; // The first Refund poolId always 2 less than collateral poolId
            locals.token = lockDealNFT.tokenOf(locals.refundPoolId);
            locals.mainCoin = lockDealNFT.tokenOf(poolId);
            locals.provider = ISimpleProvider(address(lockDealNFT.poolIdToProvider(poolId - 1)));
            locals.params = _concatParams(locals.userData.userPools[0].amount, locals.params);

            // one time token transfer for deacrease number transactions
            uint256 firstPoolId = _createFirstNFT(
                locals.provider,
                locals.token,
                locals.userData.userPools[0].user,
                locals.userData.totalAmount,
                locals.params,
                locals.tokenSignature
            );
            // create nft for main coin
            lockDealNFT.safeMintAndTransfer(
                address(this),
                locals.mainCoin,
                address(msg.sender),
                locals.userData.totalAmount,
                collateralProvider,
                locals.mainCoinSignature
            );
            // update sub collateral pool (mainCoinHolder pool)
            uint256 subPoolId = poolId + 3;
            IProvider dealProvider = lockDealNFT.poolIdToProvider(subPoolId);
            uint256[] memory subParams = dealProvider.getParams(subPoolId);
            subParams[0] += locals.userData.totalAmount;
            dealProvider.registerPool(subPoolId, subParams);

            // create mass refund pools
            //_userDataIterator(provider, userPools, totalAmount, poolId, simpleParams, refundParams);
            
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
        MassPoolsLocals memory locals;
        locals.paramsData = _validateParamsData(addressParams, params);
        require(userData.userPools.length > 0, "SimpleRefundBuilder: invalid user length");
        locals.totalAmount = userData.totalAmount;
        require(locals.totalAmount > 0, "SimpleRefundBuilder: invalid totalAmount");
        locals.simpleParams = _concatParams(userData.userPools[0].amount, params[1]);
        locals.poolId = _createFirstNFT(
            locals.paramsData.provider,
            locals.paramsData.token,
            userData.userPools[0].user,
            locals.totalAmount,
            locals.simpleParams,
            tokenSignature
        );
        locals.refundParams = _finalizeFirstNFT(
            locals.poolId,
            locals.paramsData.mainCoin,
            locals.totalAmount,
            locals.paramsData.mainCoinAmount,
            params[0][1],
            mainCoinSignature
        );
        _userDataIterator(locals.paramsData.provider, userData.userPools, locals.totalAmount, locals.poolId, locals.simpleParams, locals.refundParams);
    }
}
