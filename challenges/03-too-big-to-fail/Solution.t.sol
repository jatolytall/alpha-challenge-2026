// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract TooBigToFail is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);

        // Liquidate the under-collateralized $1B trove. The system is in Recovery Mode,
        // the trove's ICR is below the system TCR, and the Stability Pool has enough LUSD
        // to offset its debt, so the liquidation succeeds with a capped collateral offset.
        // The liquidator keeps the 0.5% gas-compensation share of the trove's ETH collateral.
        address[] memory troves = new address[](1);
        troves[0] = TARGET_TROVE;
        ITroveManager(TROVE_MANAGER).batchLiquidateTroves(troves);

        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 2500 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
