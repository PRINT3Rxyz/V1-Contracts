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
import {ShortsTrackerTimelock} from "../src/peripherals/ShortsTrackerTimelock.sol";
import {RewardClaimer} from "../src/staking/RewardClaimer.sol";
import {PriceFeedTimelock} from "../src/peripherals/PriceFeedTimelock.sol";
import {RewardTimelock} from "../src/peripherals/RewardTimelock.sol";
import {TokenManager} from "../src/access/TokenManager.sol";
import {Types} from "./Types.sol";

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
    ShortsTrackerTimelock shortsTrackerTimelock;
    RewardClaimer rewardClaimer;
    PriceFeedTimelock priceFeedTimelock;
    RewardTimelock rewardTimelock;
    TokenManager tokenManager;

    address OWNER;
    address public wbtc;
    address payable weth;
    address public usdc;
    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;
    address public usdcPriceFeed;
    uint256 private deployerKey;

    address[] ownerArray;
    address[] tokenArray; // WETH => WBTC
    uint256[] deltaDiffs;
    uint256[] longSizes;
    uint256[] shortSizes;
    string[] errors;
    address[] brrrArray;
    address[] allTokens;
    uint256[] precisions;

    function run() external returns (Types.Contracts memory) {
        helperConfig = new HelperConfig();
        Types.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        wethUsdPriceFeed = networkConfig.wethUsdPriceFeed;
        wbtcUsdPriceFeed = networkConfig.wbtcUsdPriceFeed;
        usdcPriceFeed = networkConfig.usdcPriceFeed;
        weth = networkConfig.weth;
        wbtc = networkConfig.wbtc;
        usdc = networkConfig.usdc;
        deployerKey = networkConfig.deployerKey;
        OWNER = networkConfig.deployer;

        vm.startBroadcast(deployerKey);

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
            new PositionRouter(address(vault), address(router), weth, address(shortsTracker), 30, 180000000000000);

        brrr = new BRRR();

        // Set cooldown to 0 for BrrrManager to work seamlessly
        brrrManager = new BrrrManager(address(vault), address(usdp), address(brrr), address(shortsTracker), 0);

        vaultErrorController = new VaultErrorController();

        referralStorage = new ReferralStorage();

        rewardRouter = new BrrrRewardRouter();

        rewardTracker = new RewardTracker("Staked BRRR", "sBRRR");

        rewardDistributor = new RewardDistributor(weth, address(rewardTracker));

        timelock = new Timelock(OWNER, 1, OWNER, OWNER, address(brrrManager), 0, 10, 500);

        transferStakedBrrr = new TransferStakedBrrr(address(brrr), brrrManager, address(rewardTracker));

        brrrBalance = new BrrrBalance(brrrManager, address(rewardTracker));

        orderBookReader = new OrderBookReader();

        vaultReader = new VaultReader();

        rewardReader = new RewardReader();

        referralReader = new ReferralReader();

        reader = new Reader();

        amplifier = new BrrrXpAmplifier(address(rewardTracker), address(transferStakedBrrr), weth);

        rewardClaimer = new RewardClaimer(address(amplifier), address(rewardTracker));

        usdp.addVault(address(vault));
        usdp.addVault(address(brrrManager));

        brrr.setMinter(address(brrrManager), true);
        brrr.setHandler(address(rewardTracker), true);

        ownerArray.push(OWNER);
        tokenArray.push(weth);
        tokenArray.push(wbtc);
        fastPriceFeed.initialize(1, ownerArray, ownerArray);
        fastPriceFeed.setVaultPriceFeed(address(priceFeed));
        fastPriceFeed.setMaxTimeDeviation(3600);
        fastPriceFeed.setSpreadBasisPointsIfInactive(20);
        fastPriceFeed.setSpreadBasisPointsIfChainError(500);
        deltaDiffs.push(1000000);
        deltaDiffs.push(1000000);
        fastPriceFeed.setMaxCumulativeDeltaDiffs(tokenArray, deltaDiffs);
        fastPriceFeed.setPriceDataInterval(60);

        allTokens.push(weth);
        allTokens.push(wbtc);
        allTokens.push(usdc);

        precisions.push(1000);
        precisions.push(1000);
        precisions.push(1000);

        fastPriceFeed.setTokens(allTokens, precisions);

        priceEvents.setIsPriceFeed(address(fastPriceFeed), true);

        priceFeed.setMaxStrictPriceDeviation(50000000000000000000000000000);
        priceFeed.setPriceSampleSpace(1);
        priceFeed.setSecondaryPriceFeed(address(fastPriceFeed));
        priceFeed.setIsAmmEnabled(false);
        priceFeed.setTokenConfig(weth, wethUsdPriceFeed, 8, false);
        priceFeed.setTokenConfig(wbtc, wbtcUsdPriceFeed, 8, false);
        priceFeed.setTokenConfig(usdc, usdcPriceFeed, 8, true);
        if (block.chainid == 8453) {
            priceFeed.setSequencerUptimeFeed(0xBCF85224fc0756B9Fa45aA7892530B47e10b6433);
        }

        vault.initialize(address(router), address(usdp), address(priceFeed), 2000000000000000000000000000000, 100, 100);
        vault.setInManagerMode(true);
        vault.setManager(address(brrrManager), true);
        vault.setErrorController(address(vaultErrorController));
        vault.setTokenConfig(weth, 18, 10000, 150, 0, false, true);
        if (block.chainid == 8453) {
            vault.setTokenConfig(wbtc, 18, 10000, 150, 0, false, true); // tBTC = 18 Dec on BASE
        } else {
            vault.setTokenConfig(wbtc, 8, 10000, 150, 0, false, true); // wBTC = 8 dec
        }
        vault.setTokenConfig(usdc, 6, 20000, 150, 0, true, false);
        vault.setFees(60, 5, 15, 25, 1, 40, 5000000000000000000000000000000, 10800, true);
        vault.setIsLeverageEnabled(false);
        vault.setFundingRate(3600, 100, 100);
        vault.setVaultUtils(vaultUtils);
        vault.setGov(address(timelock));

        shortsTracker.setHandler(address(positionManager), true);
        shortsTracker.setHandler(address(positionRouter), true);

        brrrManager.setInPrivateMode(false);
        brrrManager.setHandler(address(rewardRouter), true);

        referralStorage.setHandler(address(positionRouter), true);
        referralStorage.setTier(0, 1000, 5000);
        referralStorage.setTier(1, 2000, 5000);
        referralStorage.setTier(2, 3000, 5000);

        router.addPlugin(address(positionRouter));
        router.addPlugin(address(orderBook));
        router.addPlugin(address(positionManager));

        positionRouter.setReferralStorage(address(referralStorage));
        positionRouter.setPositionKeeper(address(fastPriceFeed), true);
        positionRouter.setPositionKeeper(OWNER, true);
        positionRouter.setDelayValues(0, 180, 1800);
        longSizes.push(0);
        longSizes.push(0);
        shortSizes.push(0);
        shortSizes.push(0);
        positionRouter.setMaxGlobalSizes(tokenArray, longSizes, shortSizes);
        positionRouter.setCallbackGasLimit(800000);

        errors.push("Vault: zero error");
        errors.push("Vault: already initialized");
        errors.push("Vault: invalid _maxLeverage");
        errors.push("Vault: invalid _taxBasisPoints");
        errors.push("Vault: invalid _stableTaxBasisPoints");
        errors.push("Vault: invalid _mintBurnFeeBasisPoints");
        errors.push("Vault: invalid _swapFeeBasisPoints");
        errors.push("Vault: invalid _stableSwapFeeBasisPoints");
        errors.push("Vault: invalid _marginFeeBasisPoints");
        errors.push("Vault: invalid _liquidationFeeUsd");
        errors.push("Vault: invalid _fundingInterval");
        errors.push("Vault: invalid _fundingRateFactor");
        errors.push("Vault: invalid _stableFundingRateFactor");
        errors.push("Vault: token not whitelisted");
        errors.push("Vault: _token not whitelisted");
        errors.push("Vault: invalid tokenAmount");
        errors.push("Vault: _token not whitelisted");
        errors.push("Vault: invalid tokenAmount");
        errors.push("Vault: invalid usdpAmount");
        errors.push("Vault: _token not whitelisted");
        errors.push("Vault: invalid usdpAmount");
        errors.push("Vault: invalid redemptionAmount");
        errors.push("Vault: invalid amountOut");
        errors.push("Vault: swaps not enabled");
        errors.push("Vault: _tokenIn not whitelisted");
        errors.push("Vault: _tokenOut not whitelisted");
        errors.push("Vault: invalid tokens");
        errors.push("Vault: invalid amountIn");
        errors.push("Vault: leverage not enabled");
        errors.push("Vault: insufficient collateral for fees");
        errors.push("Vault: invalid position.size");
        errors.push("Vault: empty position");
        errors.push("Vault: position size exceeded");
        errors.push("Vault: position collateral exceeded");
        errors.push("Vault: invalid liquidator");
        errors.push("Vault: empty position");
        errors.push("Vault: position cannot be liquidated");
        errors.push("Vault: invalid position");
        errors.push("Vault: invalid _averagePrice");
        errors.push("Vault: collateral should be withdrawn");
        errors.push("Vault: _size must be more than _collateral");
        errors.push("Vault: invalid OWNER");
        errors.push("Vault: mismatched tokens");
        errors.push("Vault: _collateralToken not whitelisted");
        errors.push("Vault: _collateralToken must not be a stableToken");
        errors.push("Vault: _collateralToken not whitelisted");
        errors.push("Vault: _collateralToken must be a stableToken");
        errors.push("Vault: _indexToken must not be a stableToken");
        errors.push("Vault: _indexToken not shortable");
        errors.push("Vault: invalid increase");
        errors.push("Vault: reserve exceeds pool");
        errors.push("Vault: max USDP exceeded");
        errors.push("Vault: reserve exceeds pool");
        errors.push("Vault: forbidden");
        errors.push("Vault: forbidden");
        errors.push("Vault: maxGasPrice exceeded");
        vaultErrorController.setErrors(vault, errors);

        orderBook.initialize(
            address(router), address(vault), weth, address(usdp), 100000000000000, 10000000000000000000000000000000
        );

        positionManager.setDepositFee(30);
        positionManager.setMaxGlobalSizes(tokenArray, longSizes, shortSizes);
        positionManager.setReferralStorage(address(referralStorage));
        positionManager.setShouldValidateIncreaseOrder(false);
        positionManager.setOrderKeeper(OWNER, true);
        positionManager.setLiquidator(OWNER, true);
        positionManager.setPartner(OWNER, true);
        positionManager.setAdmin(OWNER);

        rewardRouter.initialize(weth, address(brrr), address(rewardTracker), address(brrrManager));

        brrrArray.push(address(brrr));

        rewardTracker.initialize(brrrArray, address(rewardDistributor));
        // IMPORTANT STEP
        rewardTracker.setHandler(address(rewardRouter), true);
        // TransferStakedBrrr must be a handler for BrrrXpAmplifier to function
        rewardTracker.setHandler(address(transferStakedBrrr), true);
        rewardTracker.setHandler(address(rewardClaimer), true);

        amplifier.setHandler(address(rewardClaimer), true);

        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(0);

        timelock.setShouldToggleIsLeverageEnabled(true);
        timelock.setContractHandler(address(positionRouter), true);
        timelock.setContractHandler(address(positionManager), true);
        timelock.setContractHandler(OWNER, true);

        uint256[] memory priceArray = new uint256[](2);
        priceArray[0] = priceFeed.getPrice(weth, true, false, false);
        priceArray[1] = priceFeed.getPrice(wbtc, true, false, false);
        /// CRUCIAL: MUST CALL BEFORE SETTING GOV TO SHORTSTIMELOCK
        shortsTracker.setInitData(tokenArray, priceArray);

        vm.stopBroadcast();

        return Types.Contracts({
            core: Types.Core({
                brrrManager: brrrManager,
                brrr: brrr,
                vault: vault,
                vaultUtils: vaultUtils,
                vaultPriceFeed: priceFeed,
                vaultErrorController: vaultErrorController,
                shortsTracker: shortsTracker,
                positionManager: positionManager,
                positionRouter: positionRouter,
                orderBook: orderBook,
                router: router
            }),
            oracle: Types.Oracle({fastPriceFeed: fastPriceFeed, fastPriceEvents: priceEvents}),
            referral: Types.Referral({referralStorage: referralStorage, referralReader: referralReader}),
            staking: Types.Staking({
                brrrRewardRouter: rewardRouter,
                rewardTracker: rewardTracker,
                rewardDistributor: rewardDistributor,
                transferStakedBrrr: transferStakedBrrr,
                brrrBalance: brrrBalance,
                brrrXpAmplifier: amplifier,
                rewardClaimer: rewardClaimer
            }),
            peripherals: Types.Peripherals({
                timelock: timelock,
                orderBookReader: orderBookReader,
                vaultReader: vaultReader,
                rewardReader: rewardReader,
                reader: reader,
                shortsTrackerTimelock: shortsTrackerTimelock,
                priceFeedTimelock: priceFeedTimelock,
                rewardTimelock: rewardTimelock
            }),
            tokens: Types.Tokens({usdp: usdp, wbtc: wbtc, weth: weth, usdc: usdc}),
            networkConfig: networkConfig
        });
        /// Next Steps:
        /// 1. Get currency (WETH, WBTC, USDC)
        /// 2. LP Currency calling rewardRouter.mintAndStakeBrr (Never directPoolDeposit first)
        /// 3. Distribute some WETH to RewardDistributor to bootstrap rewards
        /// 4. Run the keeper script to give permissions to keepers
        /// 5. Run the governance script to give permissions to governance
        /// 6. Run the keeper script again for governance contracts
    }
}
