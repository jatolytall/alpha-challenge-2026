// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

uint256 constant FORK_BLOCK = 12465029;

address constant TROVE_MANAGER = 0xA39739EF8b0231DbFA0DcdA07d7e29faAbCf4bb2;

// The $1B Liquity position that was not liquidated during the May-19-2021 crash.
// It was later rebalanced in tx 0x27964fe8... At FORK_BLOCK it is in Recovery Mode
// (ICR between MCR and TCR) and can be liquidated via a capped offset because the
// Stability Pool holds enough LUSD to cover its debt.
address constant TARGET_TROVE = 0x903d12bf2c57A29f32365917c706ce0e1a84Cce3;
