// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Constants.sol";

contract Warmup is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), 21895252);
        vm.deal(user, 10 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);
        IWETH(WETH).deposit{value: 1 ether}();
        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(IERC20(WETH).balanceOf(user) >= 1 ether, "not enough WETH");
        console.log("Warmup solved.");
    }
}
