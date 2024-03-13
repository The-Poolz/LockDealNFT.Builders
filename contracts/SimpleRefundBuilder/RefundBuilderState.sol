// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/CalcUtils.sol";
import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ISimpleProvider.sol";
import "../Builder/BuilderInternal.sol";

/// @title RefundBuilderState contract
/// @notice This contract contains state variables and internal functions for the Simple Refund Builder
contract RefundBuilderState is BuilderInternal {
    using CalcUtils for uint256;

    // Instance of the refund provider contract
    IProvider public refundProvider;
    // Instance of the collateral provider contract
    IProvider public collateralProvider;

    struct ParamsData {
        ISimpleProvider provider; // Simple provider instance
        address token; // ERC-20 token address
        address mainCoin; // ERC-20 Main coin (or stable coin) address
        uint256 mainCoinAmount; // Amount of main coin
        uint256[] simpleParams; // Parameters for the simple provider
        uint256[] refundParams; // Parameters for the refund provider
    }

    struct Rebuilder {
        ParamsData paramsData; // Parameters data
        Builder userData; // User data (UserPool[] userPools; uint256 totalAmount)
        bytes tokenSignature; // Signature for token transfer
        bytes mainCoinSignature; // Signature for main coin transfer
        uint256 tokenPoolId; // Pool ID of the token
    }

    /// @notice Validates the parameters data provided for building refund pools
    /// @param addressParams Array containing addresses: simpleProvider, token, mainCoin
    /// @param params Array containing two sets of parameters: collateral parameters, simple provider parameters
    /// @return paramsData Parameters data structure (token, provider, mainCoin, mainCoinAmount)
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

    /// @notice Retrieves parameters data based on collateral pool ID, token amount, and first amount
    /// @param collateraPoolId Collateral pool ID
    /// @param tokenAmount Full Token amount
    /// @param firstAmount First simple provider amount
    /// @return paramsData Parameters data structure (token, provider, mainCoin, mainCoinAmount, simpleParams)
    function _getParamsData(uint256 collateraPoolId, uint256 tokenAmount, uint256 firstAmount)
        internal
        view
        returns (ParamsData memory paramsData)
    {
        // get refund pool ID
        uint256 refundPoolId = collateraPoolId - 2;
        // Ensure valid refund pool ID
        require(lockDealNFT.poolIdToProvider(refundPoolId) == refundProvider, "SimpleRefundBuilder: invalid refundPoolId");
        paramsData.token = lockDealNFT.tokenOf(refundPoolId);
        paramsData.mainCoin = lockDealNFT.tokenOf(collateraPoolId);
        paramsData.provider = ISimpleProvider(address(lockDealNFT.poolIdToProvider(refundPoolId + 1)));
        paramsData.mainCoinAmount = tokenAmount.calcAmount(collateralProvider.getParams(collateraPoolId)[2]);
        paramsData.simpleParams = paramsData.provider.getParams(refundPoolId + 1);
        paramsData.simpleParams[0] = firstAmount;
    }
}
