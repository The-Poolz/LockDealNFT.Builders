// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RefundBuilderState.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";

/// @title RefundBuilderInternal contract
/// @notice contain internal logic for Simple Refund Builder
contract RefundBuilderInternal is RefundBuilderState, FirewallConsumer {
    function _createFirstNFT(
        Rebuilder memory data
    ) internal firewallProtectedSig(0x3da709b8) returns (uint256 tokenPoolId){
        tokenPoolId = _createFirstNFT(data, msg.sender);
    }

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

    function _finalizeFirstNFT(
        Rebuilder memory data,
        uint256 collateralFinishTime
    ) internal firewallProtectedSig(0xcfc2dc78) returns (uint256[] memory refundParams) {
        refundParams = _registerRefundProvider(
        data.tokenPoolId - 1,
        _createCollateralProvider(data, collateralFinishTime));
    }

    function _registerRefundProvider(uint256 refundPoolId, uint256 collateralPoolId)
        internal
        firewallProtectedSig(0x12ff3884)
        returns (uint256[] memory refundParams)
    {
        refundParams = new uint256[](1);
        refundParams[0] = collateralPoolId;
        refundProvider.registerPool(refundPoolId, refundParams);
    }

    function _userDataIterator(
        Rebuilder memory data
    ) internal firewallProtectedSig(0xbbc1f709) {
        uint256 length = data.userData.userPools.length;
        require(length > 0, "SimpleRefundBuilder: addressParams must contain exactly 3 addresses");
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
