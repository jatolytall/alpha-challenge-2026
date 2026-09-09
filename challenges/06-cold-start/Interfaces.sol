// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface IInbox {
    function setAllowListEnabled(bool) external;
    function sendL2Message(bytes calldata messageData) external returns (uint256);
}

interface IMulticall3 {
    struct Call3Value {
        address target;
        bool allowFailure;
        uint256 value;
        bytes callData;
    }
    function aggregate3Value(Call3Value[] calldata calls) external payable returns (bytes[] memory returnData);
}

interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}