// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {Script} from "lib/forge-std/src/Script.sol";
import {WETH} from "../src/tokens/WETH.sol";
import {WBTC} from "../src/tokens/WBTC.sol";
import {Token} from "../src/tokens/Token.sol";
import {Types} from "./Types.sol";

contract HelperConfig is Script {
    Types.NetworkConfig public networkConfig;

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 1000e8;
    int256 public constant USDC_USD_PRICE = 1e8;

    uint256 public DEFAULT_ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 8453) {
            networkConfig = getBaseConfig();
        } else if (block.chainid == 84531) {
            networkConfig = getBaseGorliConfig();
        } else if (block.chainid == 84532) {
            networkConfig = getBaseSepoliaConfig();
        } else {
            networkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getBaseConfig() public pure returns (Types.NetworkConfig memory baseNetworkConfig) {
        baseNetworkConfig = Types.NetworkConfig({
            wethUsdPriceFeed: 0x71041dddad3595F9CEd3DcCFBe3D1F4b0a16Bb70,
            wbtcUsdPriceFeed: 0xCCADC697c55bbB68dc5bCdf8d3CBe83CdD4E071E,
            usdcPriceFeed: 0x7e860098F58bBFC8648a4311b374B1D669a2bc6B,
            weth: payable(0x4200000000000000000000000000000000000006),
            wbtc: 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b,
            usdc: 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913,
            deployerKey: 0x0,
            deployer: 0x4F6e437f7E90087f7090AcfE967D77ba0B4c7444
        });
    }

    function getBaseGorliConfig() public view returns (Types.NetworkConfig memory baseGorliConfig) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        baseGorliConfig = Types.NetworkConfig({
            wethUsdPriceFeed: 0xcD2A119bD1F7DF95d706DE6F2057fDD45A0503E2,
            wbtcUsdPriceFeed: 0xAC15714c08986DACC0379193e22382736796496f,
            usdcPriceFeed: 0xb85765935B4d9Ab6f841c9a00690Da5F34368bc0,
            weth: payable(0x77410Eea3dD4F7dbc8D527a3519db16a9D91B4ea),
            wbtc: 0xE9E36f0aaEd18a2f96B358173b484832407B51Da,
            usdc: 0x15DC6BB178857fD1ad54934436221211eE5d0180,
            deployerKey: privateKey,
            deployer: vm.addr(privateKey)
        });
    }

    function getBaseSepoliaConfig() public pure returns (Types.NetworkConfig memory baseSepoliaConfig) {
        baseSepoliaConfig = Types.NetworkConfig({
            wethUsdPriceFeed: 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1,
            wbtcUsdPriceFeed: 0x0FB99723Aee6f420beAD13e6bBB79b7E6F034298,
            usdcPriceFeed: 0xd30e2101a97dcbAeBCBC04F14C3f624E67A35165,
            weth: payable(0xb1E4Eca7E7A35bDf2D7627F1816A1a3Bc90213E6),
            wbtc: 0xb06794107642823DE9e078B37E60e761d7A33bFA,
            usdc: 0xF3351a1cf99c842aaD7143031643E029276a5da8,
            deployerKey: 0x0,
            deployer: 0x4F6e437f7E90087f7090AcfE967D77ba0B4c7444
        });
    }

    function getOrCreateAnvilEthConfig() public returns (Types.NetworkConfig memory anvilNetworkConfig) {
        // Check to see if we set an active network config
        if (networkConfig.wethUsdPriceFeed != address(0)) {
            return networkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        WETH wethMock = new WETH();

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        WBTC wbtcMock = new WBTC();

        MockV3Aggregator usdcPriceFeed = new MockV3Aggregator(DECIMALS, USDC_USD_PRICE);
        Token usdcMock = new Token();
        vm.stopBroadcast();

        anvilNetworkConfig = Types.NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            usdcPriceFeed: address(usdcPriceFeed),
            weth: payable(address(wethMock)),
            wbtc: address(wbtcMock),
            usdc: address(usdcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY,
            deployer: vm.addr(DEFAULT_ANVIL_PRIVATE_KEY)
        });
    }

    function getActiveNetworkConfig() external view returns (Types.NetworkConfig memory) {
        return networkConfig;
    }
}
