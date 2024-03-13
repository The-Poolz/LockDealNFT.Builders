// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";
import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ISimpleProvider.sol";
import "../Builder/BuilderInternal.sol";

/// @title RefundBuilderState contract
/// @notice contain state variables for Simple Refund Builder
contract RefundBuilderState is BuilderInternal {
    using CalcUtils for uint256;

    IProvider public refundProvider;
    IProvider public collateralProvider;

    struct ParamsData {
        ISimpleProvider provider;
        address token;
        address mainCoin;
        uint256 mainCoinAmount;
        uint256[] simpleParams;
        uint256[] refundParams;
    }

    struct Rebuilder {
        ParamsData paramsData;
        Builder userData;
        bytes tokenSignature;
        bytes mainCoinSignature;
        uint256 tokenPoolId;
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

    function _getParamsData(uint256 collateraPoolId, uint256 tokenAmount, uint256 firstAmount)
        internal
        view
        returns (ParamsData memory paramsData)
    {
        uint256 refundPoolId = collateraPoolId - 2;
        if (lockDealNFT.poolIdToProvider(refundPoolId) == refundProvider) {
            paramsData.token = lockDealNFT.tokenOf(refundPoolId);
            paramsData.mainCoin = lockDealNFT.tokenOf(collateraPoolId);
            paramsData.provider = ISimpleProvider(address(lockDealNFT.poolIdToProvider(refundPoolId + 1)));
            paramsData.mainCoinAmount = tokenAmount.calcAmount(collateralProvider.getParams(collateraPoolId)[2]);
            paramsData.simpleParams = paramsData.provider.getParams(refundPoolId + 1);
            paramsData.simpleParams[0] = firstAmount;
        }
    }
}
