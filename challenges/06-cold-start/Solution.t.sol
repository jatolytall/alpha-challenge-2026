// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract ColdStart is Test {
    address user = vm.envAddress("USER_ADDRESS");

    uint256 l1Fork;
    uint256 l2Fork;
    address constant ROLLUP = 0x23A19d23e89166adedbDcB432518AB01e4272D94;
    bool relayed;

    function setUp() public {
        l1Fork = vm.createFork(vm.envString("ETH_RPC_URL"), L1_FORK_BLOCK);
        string memory l2url = vm.envOr("ROBINHOOD_RPC_URL", string(""));
        require(bytes(l2url).length > 0, "set ROBINHOOD_RPC_URL in .env");
        l2Fork = vm.createFork(l2url, L2_FORK_BLOCK);

        vm.selectFork(l1Fork);
        vm.deal(user, 10 ether);
        vm.prank(ROLLUP);
        IInbox(INBOX).setAllowListEnabled(false);
    }

    function test_Solution() public {
        vm.selectFork(l1Fork);
        vm.recordLogs();
        vm.startBroadcast(user);

        address multicall3 = 0xcA11bde05977b3631167028862bE2a173976CA11;
        address weth = 0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73;
        address router = 0xCaf681a66D020601342297493863E78C959E5cb2;
        uint256 ethAmount = 500 ether;

        // Build the L2 calldata: wrap ETH -> approve router -> swap WETH for CASHCAT
        IMulticall3.Call3Value[] memory calls = new IMulticall3.Call3Value[](3);
        calls[0] = IMulticall3.Call3Value({
            target: weth,
            allowFailure: false,
            value: ethAmount,
            callData: abi.encodeCall(IWETH.deposit, ())
        });
        calls[1] = IMulticall3.Call3Value({
            target: weth,
            allowFailure: false,
            value: 0,
            callData: abi.encodeCall(IERC20.approve, (router, ethAmount))
        });
        calls[2] = IMulticall3.Call3Value({
            target: router,
            allowFailure: false,
            value: 0,
            callData: abi.encodeCall(ISwapRouter.exactInputSingle, (
                ISwapRouter.ExactInputSingleParams({
                    tokenIn: weth,
                    tokenOut: CASHCAT,
                    fee: 10000,
                    recipient: user,
                    amountIn: ethAmount,
                    amountOutMinimum: 1_000_000e18,
                    sqrtPriceLimitX96: 0
                })
            ))
        });

        bytes memory l2Calldata = abi.encodeCall(IMulticall3.aggregate3Value, (calls));

        // Format expected by _relay(): word0 = to, word1 = value, word8 = calldata length, then calldata
        bytes memory message = new bytes(288 + l2Calldata.length);
        assembly {
            // word 0: target
            mstore(add(message, 0x20), multicall3)
            // word 1: l2CallValue
            mstore(add(message, 0x40), ethAmount)
            // word 8: calldata length
            mstore(add(message, 0x120), mload(l2Calldata))
            // copy calldata to offset 0x140 (288)
            let src := add(l2Calldata, 0x20)
            let dst := add(message, 0x140)
            let len := mload(l2Calldata)
            for { let i := 0 } lt(i, len) { i := add(i, 0x20) } {
                mstore(add(dst, i), mload(add(src, i)))
            }
        }

        IInbox(INBOX).sendL2Message(message);

        vm.stopBroadcast();

        _relay();
        checkSolve();
    }

    // Executes every L1->L2 message you posted, on the L2, as your aliased
    // address, standing in for the sequencer. Do not edit.
    function _relay() internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        address alias_ = address(uint160(user) + uint160(0x1111000000000000000000000000000000001111));
        for (uint256 i = 0; i < logs.length; i++) {
            if (logs[i].emitter != INBOX) continue;
            bytes memory m = abi.decode(logs[i].data, (bytes));
            if (m.length < 288) continue;
            address to = address(uint160(_word(m, 0)));
            uint256 l2CallValue = _word(m, 1);
            uint256 len = _word(m, 8);
            bytes memory cd = new bytes(len);
            for (uint256 k = 0; k < len; k++) cd[k] = m[288 + k];

            vm.selectFork(l2Fork);
            vm.deal(alias_, alias_.balance + l2CallValue);
            vm.prank(alias_);
            (bool ok,) = to.call{value: l2CallValue}(cd);
            ok;
            relayed = true;
        }
    }

    function checkSolve() public view {
        require(relayed, "you never posted a message to the inbox");
        require(IERC20(CASHCAT).balanceOf(user) >= 1_000_000e18, "not enough CASHCAT");
        console.log("Cold Start solved. CASHCAT: %18e", IERC20(CASHCAT).balanceOf(user));
    }

    function _word(bytes memory m, uint256 i) private pure returns (uint256 v) {
        assembly {
            v := mload(add(add(m, 32), mul(i, 32)))
        }
    }
}
