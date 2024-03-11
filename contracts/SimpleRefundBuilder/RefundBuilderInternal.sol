// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./RefundBuilderState.sol";
import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";
import "@ironblocks/firewall-consumer/contracts/FirewallConsumer.sol";

/// @title RefundBuilderInternal contract
/// @notice contain internal logic for Simple Refund Builder
contract RefundBuilderInternal is RefundBuilderState, FirewallConsumer {
    using CalcUtils for uint256;

    function _createFirstNFT(
        ISimpleProvider provider,
        address token,
        address owner,
        uint256 totalAmount,
        uint256[] memory params,
        bytes calldata signature
    ) internal virtual override firewallProtectedSig(0x29454335) returns (uint256 poolId) {
        // one time token transfer for deacrease number transactions
        lockDealNFT.mintForProvider(owner, refundProvider);
        poolId = super._createFirstNFT(provider, token, address(refundProvider), totalAmount, params, signature);
    }

    function _createFirstNFT(
        Rebuilder memory data,
        address from
    ) internal firewallProtectedSig(0x3da709b8) returns (uint256 poolId){
        lockDealNFT.mintForProvider(data.userData.userPools[0].user, refundProvider);
        poolId = lockDealNFT.safeMintAndTransfer(
            address(refundProvider),
            data.paramsData.token,
            from,
            data.userData.totalAmount,
            data.paramsData.provider,
            data.tokenSignature
        );
        data.paramsData.provider.registerPool(poolId, data.simpleParams);
    }

    function _createCollateralProvider(
        address mainCoin,
        uint256 tokenPoolId,
        uint256 totalAmount,
        uint256 mainCoinAmount,
        uint256 collateralFinishTime,
        bytes calldata signature
    ) internal firewallProtectedSig(0x4516d406) returns (uint256 poolId) {
        poolId = lockDealNFT.safeMintAndTransfer(
            msg.sender,
            mainCoin,
            msg.sender,
            mainCoinAmount,
            collateralProvider,
            signature
        );
        uint256[] memory collateralParams = new uint256[](3);
        collateralParams[0] = totalAmount;
        collateralParams[1] = mainCoinAmount;
        collateralParams[2] = collateralFinishTime;
        collateralProvider.registerPool(poolId, collateralParams);
        lockDealNFT.cloneVaultId(poolId + 2, tokenPoolId);
    }

    function _validateParamsData(
        address[] calldata addressParams,
        uint256[][] calldata params
    ) internal view returns (ParamsData memory paramsData) {
        require(addressParams.length == 3, "invalid addressParams length");
        require(params.length == 2, "invalid params length");
        require(
            ERC165Checker.supportsInterface(addressParams[0], type(ISimpleProvider).interfaceId),
            "invalid provider type"
        );
        require(addressParams[0] != address(0), "invalid provider address");
        require(addressParams[1] != address(0), "invalid token address");
        require(addressParams[2] != address(0), "invalid mainCoin address");
        paramsData.token = addressParams[1];
        paramsData.provider = ISimpleProvider(addressParams[0]);
        paramsData.mainCoin = addressParams[2];
        paramsData.mainCoinAmount = params[0][0];
    }

    function _getRebuildData(uint256 collateraPoolId, uint256 tokenAmount)
        internal
        view
        returns (uint256 refundPoolId, ParamsData memory paramsData)
    {
        refundPoolId = collateraPoolId - 2; // there are no cases where collateraPoolId is less than 2
        paramsData.token = lockDealNFT.tokenOf(refundPoolId);
        paramsData.mainCoin = lockDealNFT.tokenOf(collateraPoolId);
        paramsData.provider = ISimpleProvider(address(lockDealNFT.poolIdToProvider(collateraPoolId - 1)));
        paramsData.mainCoinAmount = tokenAmount.calcAmount(collateralProvider.getParams(collateraPoolId)[2]);
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
        uint256 tokenPoolId,
        address mainCoin,
        uint256 totalAmount,
        uint256 mainCoinAmount,
        uint256 collateralFinishTime,
        bytes calldata signature
    ) internal firewallProtectedSig(0xcfc2dc78) returns (uint256[] memory refundParams) {
        refundParams = _registerRefundProvider(
        tokenPoolId - 1,
        _createCollateralProvider(
                mainCoin,
                tokenPoolId,
                totalAmount,
                mainCoinAmount,
                collateralFinishTime,
                signature
            )
        );
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
        ISimpleProvider provider,
        Builder memory userData,
        uint256 tokenPoolId,
        uint256[] memory simpleParams,
        uint256[] memory refundParams
    ) internal firewallProtectedSig(0xbbc1f709) {
        uint256 length = userData.userPools.length;
        require(length > 0, "invalid userPools length");
        userData.totalAmount -= userData.userPools[0].amount;
        // create refund pools for users
        for (uint256 i = 1; i < length; ) {
            uint256 userAmount = userData.userPools[i].amount;
            address user = userData.userPools[i].user;
            uint256 refundPoolId = lockDealNFT.mintForProvider(user, refundProvider);
            userData.totalAmount -= _createNewNFT(
                provider,
                tokenPoolId,
                UserPool(address(refundProvider), userAmount),
                simpleParams
            );
            refundProvider.registerPool(refundPoolId, refundParams);
            unchecked {
                ++i;
            }
        }
        // check that all tokens are distributed correctly
        assert(userData.totalAmount == 0);
    }
}
