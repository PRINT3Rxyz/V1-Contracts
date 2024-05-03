// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {IVault} from "../src/core/interfaces/IVault.sol";
import {ITimelock} from "../src/peripherals/interfaces/ITimelock.sol";

contract SetTokenConfig is Script {
    struct TokenConfig {
        address token;
        uint256 weight;
        uint256 maxUsdpAmount; // 0
        uint256 bufferAmount; // 0
    }

    ITimelock timelock = ITimelock(0xF8B9CBe37E31D8F48d0010D9b101DFD34e5923Ac);
    address vault = 0x102B73Ca761F5DFB59918f62604b54aeB2fB0b3E;

    function run() public {
        vm.startBroadcast();
        // First Token
        TokenConfig memory weth = TokenConfig({
            token: 0x4200000000000000000000000000000000000006,
            weight: 16000,
            maxUsdpAmount: 0,
            bufferAmount: 0
        });
        // Second Token
        TokenConfig memory wbtc = TokenConfig({
            token: 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b,
            weight: 16000,
            maxUsdpAmount: 0,
            bufferAmount: 0
        });
        // Third Token
        TokenConfig memory usdc = TokenConfig({
            token: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            weight: 8000,
            maxUsdpAmount: 0,
            bufferAmount: 0
        });

        uint256 wethUsdpAmount = IVault(vault).usdpAmounts(weth.token);
        uint256 wbtcUsdpAmount = IVault(vault).usdpAmounts(wbtc.token);
        uint256 usdcUsdpAmount = IVault(vault).usdpAmounts(usdc.token);

        timelock.setTokenConfig(vault, weth.token, weth.weight, 0, 0, 0, wethUsdpAmount);
        timelock.setTokenConfig(vault, wbtc.token, wbtc.weight, 0, 0, 0, wbtcUsdpAmount);
        timelock.setTokenConfig(vault, usdc.token, usdc.weight, 0, 0, 0, usdcUsdpAmount);
        // USDP Unchanged
        require(IVault(vault).usdpAmounts(weth.token) == wethUsdpAmount, "SetTokenConfig: usdpAmount changed");
        require(IVault(vault).usdpAmounts(wbtc.token) == wbtcUsdpAmount, "SetTokenConfig: usdpAmount changed");
        require(IVault(vault).usdpAmounts(usdc.token) == usdcUsdpAmount, "SetTokenConfig: usdpAmount changed");
        // Buffer Unchanged
        require(IVault(vault).bufferAmounts(weth.token) == weth.bufferAmount, "SetTokenConfig: bufferAmount changed");
        require(IVault(vault).bufferAmounts(wbtc.token) == wbtc.bufferAmount, "SetTokenConfig: bufferAmount changed");
        require(IVault(vault).bufferAmounts(usdc.token) == usdc.bufferAmount, "SetTokenConfig: bufferAmount changed");
        // Max USDP Amount Unchanged
        require(IVault(vault).maxUsdpAmounts(weth.token) == weth.maxUsdpAmount, "SetTokenConfig: maxUsdpAmount changed");
        require(IVault(vault).maxUsdpAmounts(wbtc.token) == wbtc.maxUsdpAmount, "SetTokenConfig: maxUsdpAmount changed");
        require(IVault(vault).maxUsdpAmounts(usdc.token) == usdc.maxUsdpAmount, "SetTokenConfig: maxUsdpAmount changed");
        // Weight Changed to expected
        require(IVault(vault).tokenWeights(weth.token) == weth.weight, "SetTokenConfig: weight changed");
        require(IVault(vault).tokenWeights(wbtc.token) == wbtc.weight, "SetTokenConfig: weight changed");
        require(IVault(vault).tokenWeights(usdc.token) == usdc.weight, "SetTokenConfig: weight changed");
        // Min Profit Unchanged
        require(IVault(vault).minProfitBasisPoints(weth.token) == 0, "SetTokenConfig: minProfitBasisPoints changed");
        require(IVault(vault).minProfitBasisPoints(wbtc.token) == 0, "SetTokenConfig: minProfitBasisPoints changed");
        require(IVault(vault).minProfitBasisPoints(usdc.token) == 0, "SetTokenConfig: minProfitBasisPoints changed");
        vm.stopBroadcast();
    }
}
