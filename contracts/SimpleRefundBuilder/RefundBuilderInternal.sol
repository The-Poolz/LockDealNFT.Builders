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
        Rebuilder memory data
    ) internal firewallProtectedSig(0x3da709b8) returns (uint256 poolId){
        poolId = _createFirstNFT(data, msg.sender);
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
        data.paramsData.provider.registerPool(poolId, data.paramsData.simpleParams);
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
        require(addressParams.length == 3, "SimpleRefundBuilder: addressParams must contain exactly 3 addresses");
        require(params.length == 2, "SimpleRefundBuilder: params must contain exactly 2 elements");
        require(
            ERC165Checker.supportsInterface(addressParams[0], type(ISimpleProvider).interfaceId),
            "SimpleRefundBuilder: provider must be ISimpleProvider"
        );
        require(addressParams[0] != address(0), "SimpleRefundBuilder: invalid provider address");
        require(addressParams[1] != address(0), "SimpleRefundBuilder: invalid token address");
        require(addressParams[2] != address(0), "SimpleRefundBuilder: invalid mainCoin address");
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
        ParamsData memory paramsData,
        Builder memory userData,
        uint256 tokenPoolId
    ) internal firewallProtectedSig(0xbbc1f709) {
        uint256 length = userData.userPools.length;
        require(length > 0, "SimpleRefundBuilder: addressParams must contain exactly 3 addresses");
        userData.totalAmount -= userData.userPools[0].amount;
        // create refund pools for users
        for (uint256 i = 1; i < length; ) {
            uint256 userAmount = userData.userPools[i].amount;
            address user = userData.userPools[i].user;
            uint256 refundPoolId = lockDealNFT.mintForProvider(user, refundProvider);
            userData.totalAmount -= _createNewNFT(
                paramsData.provider,
                tokenPoolId,
                UserPool(address(refundProvider), userAmount),
                paramsData.simpleParams
            );
            refundProvider.registerPool(refundPoolId, paramsData.refundParams);
            unchecked {
                ++i;
            }
        }
        // check that all tokens are distributed correctly
        assert(userData.totalAmount == 0);
    }

    ///@dev `_mergingParams` used for `onERC721Received`, `_concatParams` used for `buildMassPools` for calldata params
    function _mergingParams(uint amount, uint256[] memory params) internal pure returns (uint256[] memory result) {
        uint256 length = params.length;
        result = new uint256[](length + 1);
        result[0] = amount;
        for (uint256 i = 0; i < length; ) {
            result[i + 1] = params[i];
            unchecked {
                ++i;
            }
        }
    }
}
