// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VaultPriceFeed} from "../src/core/VaultPriceFeed.sol";
import {FastPriceEvents} from "../src/oracle/FastPriceEvents.sol";
import {FastPriceFeed} from "../src/oracle/FastPriceFeed.sol";
import {Vault} from "../src/core/Vault.sol";
import {USDP} from "../src/tokens/USDP.sol";
import {Router} from "../src/core/Router.sol";
import {VaultUtils} from "../src/core/VaultUtils.sol";
import {ShortsTracker} from "../src/core/ShortsTracker.sol";
import {PositionManager} from "../src/core/PositionManager.sol";
import {PositionRouter} from "../src/core/PositionRouter.sol";
import {OrderBook} from "../src/core/OrderBook.sol";
import {BRRR} from "../src/core/BRRR.sol";
import {BrrrManager} from "../src/core/BrrrManager.sol";
import {VaultErrorController} from "../src/core/VaultErrorController.sol";
import {WBTC} from "../src/tokens/WBTC.sol";
import {WETH} from "../src/tokens/WETH.sol";
import {ReferralStorage} from "../src/referrals/ReferralStorage.sol";
import {BrrrRewardRouter} from "../src/staking/BrrrRewardRouter.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";
import {RewardDistributor} from "../src/staking/RewardDistributor.sol";
import {ReferralReader} from "../src/referrals/ReferralReader.sol";
import {Timelock} from "../src/peripherals/Timelock.sol";
import {OrderBookReader} from "../src/peripherals/OrderBookReader.sol";
import {VaultReader} from "../src/peripherals/VaultReader.sol";
import {RewardReader} from "../src/peripherals/RewardReader.sol";
import {TransferStakedBrrr} from "../src/staking/TransferStakedBrrr.sol";
import {BrrrBalance} from "../src/staking/BrrrBalance.sol";
import {Reader} from "../src/peripherals/Reader.sol";
import {Token} from "../src/tokens/Token.sol";
import {BrrrXpAmplifier} from "../src/staking/BrrrXpAmplifier.sol";

contract DeployP3 is Script {
    HelperConfig public helperConfig;
    VaultPriceFeed priceFeed;
    FastPriceEvents priceEvents;
    FastPriceFeed fastPriceFeed;
    Vault vault;
    USDP usdp;
    Router router;
    VaultUtils vaultUtils;
    ShortsTracker shortsTracker;
    PositionManager positionManager;
    PositionRouter positionRouter;
    OrderBook orderBook;
    BRRR brrr;
    BrrrManager brrrManager;
    VaultErrorController vaultErrorController;
    ReferralStorage referralStorage;
    BrrrRewardRouter rewardRouter;
    RewardTracker rewardTracker;
    RewardDistributor rewardDistributor;
    Timelock timelock;
    TransferStakedBrrr transferStakedBrrr;
    BrrrBalance brrrBalance;
    OrderBookReader orderBookReader;
    VaultReader vaultReader;
    RewardReader rewardReader;
    ReferralReader referralReader;
    Reader reader;
    BrrrXpAmplifier amplifier;

    address public wbtc;
    address payable weth;
    address public usdc;
    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    address public usdcPriceFeed;
    uint256 public deployerKey;

    uint256 public constant LARGE_AMOUNT = 1e30;
    uint256 public constant DEPOSIT_AMOUNT = 1e22;
    uint256 public constant SMALL_AMOUNT = 1e20;

    function run()
        external
        returns (
            VaultPriceFeed,
            FastPriceEvents,
            FastPriceFeed,
            Vault,
            USDP,
            Router,
            VaultUtils,
            ShortsTracker,
            OrderBook,
            PositionManager,
            PositionRouter,
            BRRR,
            BrrrManager,
            VaultErrorController,
            ReferralStorage,
            BrrrRewardRouter,
            RewardTracker,
            RewardDistributor,
            Timelock,
            TransferStakedBrrr,
            BrrrBalance,
            OrderBookReader,
            VaultReader,
            RewardReader,
            ReferralReader,
            Reader,
            BrrrXpAmplifier,
            HelperConfig
        )
    {
        HelperConfig helperConfig = new HelperConfig(); // This comes with our mocks!

        (wethUsdPriceFeed, wbtcUsdPriceFeed, usdcPriceFeed, weth, wbtc, usdc, deployerKey) =
            helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        address OWNER = msg.sender;

        priceFeed = new VaultPriceFeed();

        priceEvents = new FastPriceEvents();

        fastPriceFeed = new FastPriceFeed(300, 300, 0, 300, address(priceEvents), OWNER);

        vault = new Vault();

        usdp = new USDP(address(vault));

        router = new Router(address(vault), address(usdp), weth);

        vaultUtils = new VaultUtils(vault);

        shortsTracker = new ShortsTracker(address(vault));

        orderBook = new OrderBook();

        positionManager =
            new PositionManager(address(vault), address(router), address(shortsTracker), weth, 50, address(orderBook));

        positionRouter =
            new PositionRouter(address(vault), address(router), weth, address(shortsTracker), 30, 300000000000000);

        brrr = new BRRR();

        // Set cooldown to 0 for BrrrManager to work seamlessly
        brrrManager = new BrrrManager(address(vault), address(usdp), address(brrr), address(shortsTracker), 0);

        vaultErrorController = new VaultErrorController();

        referralStorage = new ReferralStorage();

        rewardRouter = new BrrrRewardRouter();

        rewardTracker = new RewardTracker("Staked BRRR", "sBRRR");

        rewardDistributor = new RewardDistributor(weth, address(rewardTracker));

        timelock = new Timelock(OWNER, 1, OWNER, OWNER, address(brrrManager), address(rewardRouter), 0, 10, 500);

        transferStakedBrrr = new TransferStakedBrrr(address(brrr), brrrManager, address(rewardTracker));

        brrrBalance = new BrrrBalance(brrrManager, address(rewardTracker));

        orderBookReader = new OrderBookReader();

        vaultReader = new VaultReader();

        rewardReader = new RewardReader();

        referralReader = new ReferralReader();

        reader = new Reader();

        amplifier = new BrrrXpAmplifier(address(rewardTracker), address(transferStakedBrrr), weth);

        vm.stopBroadcast();
        return (
            priceFeed,
            priceEvents,
            fastPriceFeed,
            vault,
            usdp,
            router,
            vaultUtils,
            shortsTracker,
            orderBook,
            positionManager,
            positionRouter,
            brrr,
            brrrManager,
            vaultErrorController,
            referralStorage,
            rewardRouter,
            rewardTracker,
            rewardDistributor,
            timelock,
            transferStakedBrrr,
            brrrBalance,
            orderBookReader,
            vaultReader,
            rewardReader,
            referralReader,
            reader,
            amplifier,
            helperConfig
        );
    }
}
