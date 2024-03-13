// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@poolzfinance/poolz-helper-v2/contracts/interfaces/ISimpleProvider.sol";
import "../Builder/BuilderInternal.sol";

/// @title RefundBuilderState contract
/// @notice contain state variables for Simple Refund Builder
contract RefundBuilderState is BuilderInternal {
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
}
