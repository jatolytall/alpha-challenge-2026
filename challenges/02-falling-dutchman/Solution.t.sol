// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";
import "./Interfaces.sol";
import "./Constants.sol";

contract FallingDutchman is Test {
    address user = vm.envAddress("USER_ADDRESS");

    function setUp() public {
        vm.createSelectFork(vm.envString("ETH_RPC_URL"), FORK_BLOCK);
        vm.deal(user, 0.1 ether);
    }

    function test_Solution() public {
        vm.startBroadcast(user);

        // Buy KNC on Uniswap v1 with almost all of our ETH. This is the currency the
        // mispriced DutchX auction wants as payment.
        uint256 kncBought = IUniswapV1Exchange(UNI_V1_KNC_EXCHANGE).ethToTokenSwapInput{value: 0.0995 ether}(
            1, block.timestamp
        );

        // Deposit the KNC into DutchX and bid in the running WETH->KNC auction, whose price
        // had decayed to a tiny fraction of fair value after sitting unbid for ~23 hours.
        IERC20(KNC).approve(DUTCHX, kncBought);
        IDutchExchange dx = IDutchExchange(DUTCHX);
        dx.deposit(KNC, kncBought);

        uint256 auctionIndex = dx.getAuctionIndex(WETH, KNC);
        dx.postBuyOrder(WETH, KNC, auctionIndex, kncBought);

        // Claim the (very cheap) WETH we just bought, withdraw it from DutchX, and unwrap it.
        (uint256 wethReturned,) = dx.claimBuyerFunds(WETH, KNC, user, auctionIndex);
        dx.withdraw(WETH, wethReturned);
        IWETH(WETH).withdraw(wethReturned);

        vm.stopBroadcast();
        checkSolve();
    }

    function checkSolve() public view {
        require(user.balance >= 4 ether, "not enough ETH");
        console.log("Solved. Ending balance in ETH: %18e", user.balance);
    }
}
