// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "forge-std/Script.sol";
import {WETH} from "../src/tokens/WETH.sol";
import {WBTC} from "../src/tokens/WBTC.sol";
import {Token} from "../src/tokens/Token.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant USDC_USD_PRICE = 1e8;

    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address usdcPriceFeed;
        address payable weth;
        address wbtc;
        address usdc;
        uint256 deployerKey;
    }

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig() public returns (NetworkConfig memory sepoliaNetworkConfig) {
        WBTC _wbtc = new WBTC();
        Token _usdc = new Token();
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH / USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43,
            usdcPriceFeed: 0xA2F78ab2355fe2f984D808B5CeE7FD0A93D5270E,
            // WETH altered. Re-deploy for Sepolia.
            weth: payable(0x5f871b68DB327999dE84B9757F30F9B4dc73186A),
            wbtc: address(_wbtc),
            usdc: address(_usdc),
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            ETH_USD_PRICE
        );
        WETH wethMock = new WETH();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(
            DECIMALS,
            BTC_USD_PRICE
        );
        WBTC wbtcMock = new WBTC();

        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(
            DECIMALS,
            USDC_USD_PRICE
        );
        Token usdcMock = new Token();
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed), // ETH / USD
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            usdcPriceFeed: address(usdcPriceFeed),
            weth: payable(address(wethMock)),
            wbtc: address(wbtcMock),
            usdc: address(usdcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }
}
