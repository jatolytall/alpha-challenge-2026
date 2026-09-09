// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

uint256 constant FORK_BLOCK = 9462777;

address constant DUTCHX = 0xb9812E2fA995EC53B5b6DF34d21f9304762C5497;

// The auction that had fallen almost all the way to zero at FORK_BLOCK: sellToken WETH,
// buyToken KNC. Anyone posting a KNC buy order there received WETH at a small fraction of
// its market price.
address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
address constant KNC = 0xdd974D5C2e2928deA5F71b9825b8b646686BD200;

// Uniswap v1 ETH<->KNC pool, used to source the KNC needed to bid in the DutchX auction.
address constant UNI_V1_KNC_EXCHANGE = 0x49c4f9bc14884f6210F28342ceD592A633801a8b;
