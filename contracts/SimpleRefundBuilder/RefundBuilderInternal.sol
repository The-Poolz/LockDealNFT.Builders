// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RefundBuilderState.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";

/// @title RefundBuilderInternal contract
/// @notice Contains internal logic for the Simple Refund Builder
contract RefundBuilderInternal is RefundBuilderState, FirewallConsumer {
    /// @notice Creates the first NFT for the refund provider
    /// @param data Rebuilder struct containing token data
    /// @return tokenPoolId Token pool ID of the created simple NFT
    function _createFirstNFT(
        Rebuilder memory data
    ) internal firewallProtectedSig(0x3da709b8) returns (uint256 tokenPoolId){
        tokenPoolId = _createFirstNFT(data, msg.sender);
    }

    /// @notice Creates the first NFT for the refund provider with specified sender
    /// @param data Rebuilder struct containing token data
    /// @param from Address of the sender
    /// @return tokenPoolId Token pool ID of the created simple NFT
    function _createFirstNFT(
        Rebuilder memory data,
        address from
    ) internal firewallProtectedSig(0x3da709b8) returns (uint256 tokenPoolId){
        lockDealNFT.mintForProvider(data.userData.userPools[0].user, refundProvider);
        tokenPoolId = lockDealNFT.safeMintAndTransfer(
            address(refundProvider),
            data.paramsData.token,
            from,
            data.userData.totalAmount,
            data.paramsData.provider,
            data.tokenSignature
        );
        data.paramsData.provider.registerPool(tokenPoolId, data.paramsData.simpleParams);
    }

    /// @notice Creates the collateral provider
    /// @param data Rebuilder struct containing mainCoin data
    /// @param collateralFinishTime Finish time for refund
    /// @return poolId Collateral pool ID
    function _createCollateralProvider(
        Rebuilder memory data,
        uint256 collateralFinishTime
    ) internal firewallProtectedSig(0x4516d406) returns (uint256 poolId) {
        poolId = lockDealNFT.safeMintAndTransfer(
            msg.sender,
            data.paramsData.mainCoin,
            msg.sender,
            data.paramsData.mainCoinAmount,
            collateralProvider,
            data.mainCoinSignature
        );
        uint256[] memory collateralParams = new uint256[](3);
        collateralParams[0] = data.userData.totalAmount;
        collateralParams[1] = data.paramsData.mainCoinAmount;
        collateralParams[2] = collateralFinishTime;
        collateralProvider.registerPool(poolId, collateralParams);
        lockDealNFT.cloneVaultId(poolId + 2, data.tokenPoolId);
    }

    /// @notice Updates collateral data
    /// @param data Rebuilder struct containing necessary data
    /// @param from Address of the sender
    /// @param subPoolId ID of the sub collateral pool - main coin holder pool
    function _updateCollateralData(
        Rebuilder memory data,
        address from,
        uint256 subPoolId
    ) internal firewallProtectedSig(0x54c3ed4d) {
        IProvider dealProvider = lockDealNFT.poolIdToProvider(subPoolId);
        lockDealNFT.safeMintAndTransfer(
            address(this),
            data.paramsData.mainCoin,
            from,
            data.paramsData.mainCoinAmount,
            dealProvider,
            data.mainCoinSignature
        );
        // update sub collateral pool (mainCoinHolder pool)
        uint256[] memory subParams = dealProvider.getParams(subPoolId);
        subParams[0] += data.paramsData.mainCoinAmount;
        dealProvider.registerPool(subPoolId, subParams);
    }

    /// @notice Finalizes the creation of the first NFT
    /// @param data Rebuilder struct containing necessary data
    /// @param collateralFinishTime Finish time for collateral
    /// @return refundParams Refund parameter `poolIdToCollateralId`
    function _finalizeFirstNFT(
        Rebuilder memory data,
        uint256 collateralFinishTime
    ) internal firewallProtectedSig(0xcfc2dc78) returns (uint256[] memory refundParams) {
        refundParams = _registerRefundProvider(
        data.tokenPoolId - 1,
        _createCollateralProvider(data, collateralFinishTime));
    }

    /// @notice Registers the refund provider
    /// @param refundPoolId Refund pool ID
    /// @param collateralPoolId Collateral pool ID
    /// @return refundParams Refund parameter poolIdToCollateralId
    function _registerRefundProvider(uint256 refundPoolId, uint256 collateralPoolId)
        internal
        firewallProtectedSig(0x12ff3884)
        returns (uint256[] memory refundParams)
    {
        refundParams = new uint256[](1);
        refundParams[0] = collateralPoolId;
        refundProvider.registerPool(refundPoolId, refundParams);
    }

    /// @notice Iterates over user data to create refund pools for each user
    /// @param data Users data, paramsData, tokenPoolId, simple provider address
    function _userDataIterator(
        Rebuilder memory data
    ) internal firewallProtectedSig(0xbbc1f709) {
        uint256 length = data.userData.userPools.length;
        data.userData.totalAmount -= data.userData.userPools[0].amount;
        // create refund pools for users
        for (uint256 i = 1; i < length; ) {
            uint256 userAmount = data.userData.userPools[i].amount;
            address user = data.userData.userPools[i].user;
            uint256 refundPoolId = lockDealNFT.mintForProvider(user, refundProvider);
            data.userData.totalAmount -= _createNewNFT(
                data.paramsData.provider,
                data.tokenPoolId,
                UserPool(address(refundProvider), userAmount),
                data.paramsData.simpleParams
            );
            refundProvider.registerPool(refundPoolId, data.paramsData.refundParams);
            unchecked {
                ++i;
            }
        }
        // check that all tokens are distributed correctly
        assert(data.userData.totalAmount == 0);
    }
}
