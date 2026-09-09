// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import "../../src/Interfaces.sol";

/// @dev Permissionless Uniswap V3 fee adapter; it owns the X Layer V3 factory, so it is the only
/// address allowed to call `pool.collectProtocol`. Anyone may ask it to sweep pools into the jar.
interface IV3OpenFeeAdapter {
    struct CollectParams {
        address pool;
        uint128 amount0Requested;
        uint128 amount1Requested;
    }

    struct Collected {
        uint128 amount0Collected;
        uint128 amount1Collected;
    }

    function collect(CollectParams[] calldata collectParams) external returns (Collected[] memory);
}

/// @dev OptimismBridgedResourceFirepit: takes `threshold` UNI, then releases the jar's assets.
interface IFirepit {
    function nonce() external view returns (uint256);
    function threshold() external view returns (uint256);
    function release(uint256 nonce, address[] calldata assets, address recipient) external;
}

interface ISwapRouter02 {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256);
}

contract Firepit is Test {
    address user = vm.envAddress("USER_ADDRESS");
    address constant UNI = 0x57FB37d035e6Ad0E687E0a50dC3F515691deB815;
    address constant USDT = 0x779Ded0c9e1022225f8E0630b35a9b54bE713736;

    address constant ADAPTER = 0x6A88EF2e6511CAFfE2D006e260e7A5d1E7D4d7D7;
    address constant FIREPIT = 0xe122E231cb52aea99690963Fd73E91e33E97468f;
    address constant ROUTER = 0x4f0C28f5926AFDA16bf2506D5D9e57Ea190f9bcA;

    address constant USDG = 0x4ae46a509F6b1D9056937BA4500cb143933D2dc8;
    address constant WOKB = 0xe538905cf8410324e03A5A23C1c177a474D59b2b;

    function setUp() public {
        vm.createSelectFork(vm.envString("XLAYER_RPC_URL"), 68413600);
        vm.etch(0x4200000000000000000000000000000000000010, hex"60006000f3");
        deal(UNI, user, 2000e18);
    }

    function test_Solution() public {
        vm.startPrank(user);

        // 1. Uncollected V3 protocol fees sit inside the pools, not in the jar. The adapter owns
        //    the factory and its `collect` is permissionless, so sweep the pools that hold the
        //    stablecoin/WOKB fees into the jar first.
        address[12] memory pools = [
            0x63d62734847E55A266FCa4219A9aD0a02D5F6e02, // USD₮0 / WOKB   0.30%
            0xe1071DB4691b325c709854DC3D5CcD5d77e62Ed1, // USDG  / *      0.05%
            0xe3BE6A0137f1b0602Fc1a4841686f43B340a5082, // USD₮0 / WOKB   0.05%
            0x0cBe0dBE1400e57f371a38BD3b9bC80F7C3676dA, // USDG  / USD₮0  0.01%
            0x77ef18adF35f62B2Ad442e4370cDbC7fe78B7dcC, // USD₮0 / *      0.05%
            0x4651300221f345a4c6F566079BD1DDC291049c7d, // USD₮0 / *      0.05%
            0x2a2B11730C2b6d99a58034A869dd810D7300a7b2, // USDG  / wNVDAx 0.05%
            0x5fcFb33C9AB1665FeE892eB2aF163e863a874D73, // USD₮0 / *      0.05%
            0xc44bd9c8589026D28D1632d7b86b2Efb6cDc8fd2, // USDG  / wAAPLx 0.05%
            0x9e485CC2Ec10E87A9B6e58602889Df392B7F6453, // USD₮0 / WOKB   0.01%
            0xa575234CC82bE1DD41D133cA33E879287d6751A0, // USD₮0 / wNVDAx 0.30%
            0x8CE66218A6310765307e7ab2d11BcfF7cC2ea1F1 // USDG  / *      0.05%
        ];

        IV3OpenFeeAdapter.CollectParams[] memory params = new IV3OpenFeeAdapter.CollectParams[](pools.length);
        for (uint256 i; i < pools.length; ++i) {
            params[i] = IV3OpenFeeAdapter.CollectParams({
                pool: pools[i],
                amount0Requested: type(uint128).max,
                amount1Requested: type(uint128).max
            });
        }
        IV3OpenFeeAdapter(ADAPTER).collect(params);

        // 2. Burn the 2000 UNI threshold and release the jar to ourselves.
        IERC20(UNI).approve(FIREPIT, IFirepit(FIREPIT).threshold());

        address[] memory assets = new address[](3);
        assets[0] = USDT;
        assets[1] = USDG;
        assets[2] = WOKB;
        IFirepit(FIREPIT).release(IFirepit(FIREPIT).nonce(), assets, user);

        // 3. Convert the non-USD₮0 proceeds into USD₮0.
        _swapAllToUsdt(USDG, 100);
        _swapAllToUsdt(WOKB, 500);

        vm.stopPrank();
        checkSolve();
    }

    function _swapAllToUsdt(address tokenIn, uint24 fee) internal {
        uint256 amountIn = IERC20(tokenIn).balanceOf(user);
        if (amountIn == 0) return;

        IERC20(tokenIn).approve(ROUTER, amountIn);
        ISwapRouter02(ROUTER).exactInputSingle(
            ISwapRouter02.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: USDT,
                fee: fee,
                recipient: user,
                amountIn: amountIn,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            })
        );
    }

    function checkSolve() public view {
        require(IERC20(USDT).balanceOf(user) >= 45_000e6, "not enough USDT");
        console.log("Firepit solved. USDT: %6e", IERC20(USDT).balanceOf(user));
    }
}
