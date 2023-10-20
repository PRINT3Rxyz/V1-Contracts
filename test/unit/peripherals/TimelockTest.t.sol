// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {VaultPriceFeed} from "../../../src/core/VaultPriceFeed.sol";
import {FastPriceEvents} from "../../../src/oracle/FastPriceEvents.sol";
import {FastPriceFeed} from "../../../src/oracle/FastPriceFeed.sol";
import {Vault} from "../../../src/core/Vault.sol";
import {USDP} from "../../../src/tokens/USDP.sol";
import {Router} from "../../../src/core/Router.sol";
import {VaultUtils} from "../../../src/core/VaultUtils.sol";
import {ShortsTracker} from "../../../src/core/ShortsTracker.sol";
import {PositionManager} from "../../../src/core/PositionManager.sol";
import {PositionRouter} from "../../../src/core/PositionRouter.sol";
import {OrderBook} from "../../../src/core/OrderBook.sol";
import {BRRR} from "../../../src/core/BRRR.sol";
import {BrrrManager} from "../../../src/core/BrrrManager.sol";
import {VaultErrorController} from "../../../src/core/VaultErrorController.sol";
import {WBTC} from "../../../src/tokens/WBTC.sol";
import {WETH} from "../../../src/tokens/WETH.sol";
import {ReferralStorage} from "../../../src/referrals/ReferralStorage.sol";
import {BrrrRewardRouter} from "../../../src/staking/BrrrRewardRouter.sol";
import {RewardTracker} from "../../../src/staking/RewardTracker.sol";
import {RewardDistributor} from "../../../src/staking/RewardDistributor.sol";
import {ReferralReader} from "../../../src/referrals/ReferralReader.sol";
import {Timelock} from "../../../src/peripherals/Timelock.sol";
import {OrderBookReader} from "../../../src/peripherals/OrderBookReader.sol";
import {VaultReader} from "../../../src/peripherals/VaultReader.sol";
import {RewardReader} from "../../../src/peripherals/RewardReader.sol";
import {TransferStakedBrrr} from "../../../src/staking/TransferStakedBrrr.sol";
import {BrrrBalance} from "../../../src/staking/BrrrBalance.sol";
import {Reader} from "../../../src/peripherals/Reader.sol";
import {Token} from "../../../src/tokens/Token.sol";
import {PriceFeedTimelock} from "../../../src/peripherals/PriceFeedTimelock.sol";
import {ShortsTrackerTimelock} from "../../../src/peripherals/ShortsTrackerTimelock.sol";

contract TimelockTest is Test {
    address public OWNER;
    address public USER = makeAddr("user");

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
    PriceFeedTimelock priceFeedTimelock;
    ShortsTrackerTimelock shortsTrackerTimelock;
    TransferStakedBrrr transferStakedBrrr;
    BrrrBalance brrrBalance;
    OrderBookReader orderBookReader;
    VaultReader vaultReader;
    RewardReader rewardReader;
    ReferralReader referralReader;
    Reader reader;

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

    uint256[] longSizes;
    uint256[] shortSizes;
    string[] errors;
    uint256[] deltaDiffs;
    address[] brrrArray;

    // Singular Token Arrays
    address[] wbtcArray;
    address[] wethArray;
    address[] usdcArray;

    // Token Path Arrays
    address[] tokenArray; // WETH => WBTC
    address[] wbtcToUsdcArray; // WBTC => USDC
    address[] wethToUsdcArray; // WETH => USDC
    address[] usdcToWethArray; // USDC => WETH
    // Address Arrays
    address[] ownerArray;
    bool[] boolArray;

    uint256[] numberArray;

    function setUp() public {
        OWNER = msg.sender;
        helperConfig = new HelperConfig();
        (wethUsdPriceFeed, wbtcUsdPriceFeed, usdcPriceFeed, weth, wbtc, usdc, deployerKey) =
            helperConfig.activeNetworkConfig();
        vm.deal(OWNER, 1e18 ether);
        vm.startPrank(OWNER);

        /// Note Full Deployment Steps To Avoid Stack too Deep Error

        priceFeed = new VaultPriceFeed();

        priceEvents = new FastPriceEvents();

        fastPriceFeed = new FastPriceFeed(300, 300, 0, 300, address(priceEvents), OWNER);

        vault = new Vault();

        usdp = new USDP(address(vault));

        router = new Router(address(vault), address(usdp), weth);

        vaultUtils = new VaultUtils(vault);

        shortsTracker = new ShortsTracker(address(vault));

        orderBook = new OrderBook();

        // Need to deploy Position Utils Library before
        positionManager =
            new PositionManager(address(vault), address(router), address(shortsTracker), weth, 50, address(orderBook));

        positionRouter =
            new PositionRouter(address(vault), address(router), weth, address(shortsTracker), 30, 300000000000000);

        brrr = new BRRR();

        brrrManager = new BrrrManager(address(vault), address(usdp), address(brrr), address(shortsTracker), 900);

        vaultErrorController = new VaultErrorController();

        WBTC(wbtc).mint(OWNER, LARGE_AMOUNT);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        Token(usdc).mint(OWNER, LARGE_AMOUNT);

        referralStorage = new ReferralStorage();

        rewardRouter = new BrrrRewardRouter();

        rewardTracker = new RewardTracker("Staked BRRR", "sBRRR");

        rewardDistributor = new RewardDistributor(weth, address(rewardTracker));

        // Increased maxTokenSupply to test minting
        timelock = new Timelock(OWNER, 1, OWNER, OWNER, address(brrrManager), address(rewardRouter), 1e60, 10, 500);

        priceFeedTimelock = new PriceFeedTimelock(OWNER, 1, OWNER);

        shortsTrackerTimelock = new ShortsTrackerTimelock(OWNER, 1, 1, 10000);

        transferStakedBrrr = new TransferStakedBrrr(address(brrr), brrrManager, address(rewardTracker));

        brrrBalance = new BrrrBalance(brrrManager, address(rewardTracker));

        orderBookReader = new OrderBookReader();

        vaultReader = new VaultReader();

        rewardReader = new RewardReader();

        referralReader = new ReferralReader();

        reader = new Reader();
        console.log("Deployed contracts");

        usdp.addVault(address(vault));
        usdp.addVault(address(brrrManager));

        brrr.setMinter(address(brrrManager), true);
        brrr.setHandler(address(rewardTracker), true);

        ownerArray.push(OWNER);
        tokenArray.push(weth);
        tokenArray.push(wbtc);
        address[] memory _ownerArray = ownerArray;
        address[] memory _tokenArray = tokenArray;
        fastPriceFeed.initialize(1, _ownerArray, _ownerArray);
        fastPriceFeed.setVaultPriceFeed(address(priceFeed));
        fastPriceFeed.setMaxTimeDeviation(3600);
        fastPriceFeed.setSpreadBasisPointsIfInactive(50);
        fastPriceFeed.setSpreadBasisPointsIfChainError(500);
        deltaDiffs.push(200000);
        deltaDiffs.push(200000);
        uint256[] memory _deltaDiffs = deltaDiffs;
        fastPriceFeed.setMaxCumulativeDeltaDiffs(_tokenArray, _deltaDiffs);
        fastPriceFeed.setPriceDataInterval(60);

        priceEvents.setIsPriceFeed(address(fastPriceFeed), true);

        priceFeed.setMaxStrictPriceDeviation(50000000000000000000000000000);
        priceFeed.setPriceSampleSpace(1);
        priceFeed.setSecondaryPriceFeed(address(fastPriceFeed));
        priceFeed.setIsAmmEnabled(false);
        priceFeed.setTokenConfig(weth, wethUsdPriceFeed, 8, false);
        priceFeed.setTokenConfig(wbtc, wbtcUsdPriceFeed, 8, false);
        priceFeed.setTokenConfig(usdc, usdcPriceFeed, 8, true);

        vault.initialize(address(router), address(usdp), address(priceFeed), 2000000000000000000000000000000, 100, 100);
        vault.setInManagerMode(true);
        vault.setManager(address(brrrManager), true);
        vault.setErrorController(address(vaultErrorController));
        vault.setTokenConfig(weth, 18, 10000, 150, 0, false, true);
        vault.setTokenConfig(wbtc, 8, 10000, 150, 0, false, true);
        vault.setTokenConfig(usdc, 6, 20000, 150, 0, true, false);
        vault.setFees(15, 5, 15, 15, 1, 10, 2000000000000000000000000000000, 86400, true);
        vault.setIsLeverageEnabled(false);
        vault.setFundingRate(3600, 100, 100);
        vault.setVaultUtils(vaultUtils);
        vault.setGov(address(timelock));

        shortsTracker.setHandler(address(positionManager), true);
        shortsTracker.setHandler(address(positionRouter), true);

        brrrManager.setInPrivateMode(false);
        brrrManager.setHandler(address(rewardRouter), true);

        referralStorage.setHandler(address(positionRouter), true);

        router.addPlugin(address(positionRouter));
        router.addPlugin(address(orderBook));
        router.addPlugin(address(positionManager));
        WBTC(wbtc).approve(address(router), LARGE_AMOUNT);
        WETH(weth).approve(address(router), LARGE_AMOUNT);
        Token(usdc).approve(address(router), LARGE_AMOUNT);

        positionRouter.setReferralStorage(address(referralStorage));
        positionRouter.setPositionKeeper(address(fastPriceFeed), true);
        positionRouter.setPositionKeeper(OWNER, true);
        positionRouter.setPositionKeeper(USER, true);
        positionRouter.setDelayValues(0, 180, 1800);
        longSizes.push(40000000000000000000000000000000000000);
        longSizes.push(45000000000000000000000000000000000000);
        shortSizes.push(35000000000000000000000000000000000000);
        shortSizes.push(45000000000000000000000000000000000000);
        uint256[] memory _longSizes = longSizes;
        uint256[] memory _shortSizes = shortSizes;
        positionRouter.setMaxGlobalSizes(_tokenArray, _longSizes, _shortSizes);
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
        errors.push("Vault: invalid msg.sender");
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
        string[] memory _errors = errors;
        vaultErrorController.setErrors(vault, _errors);

        orderBook.initialize(
            address(router), address(vault), weth, address(usdp), 300000000000000, 10000000000000000000000000000000
        );

        positionManager.setDepositFee(30);
        positionManager.setMaxGlobalSizes(_tokenArray, _longSizes, _shortSizes);
        positionManager.setReferralStorage(address(referralStorage));
        positionManager.setShouldValidateIncreaseOrder(false);
        positionManager.setOrderKeeper(OWNER, true);
        positionManager.setOrderKeeper(USER, true);
        positionManager.setLiquidator(OWNER, true);
        positionManager.setLiquidator(USER, true);
        positionManager.setPartner(OWNER, true);

        rewardRouter.initialize(weth, address(brrr), address(rewardTracker), address(brrrManager));

        brrrArray.push(address(brrr));
        address[] memory _depositTokens = brrrArray;
        rewardTracker.initialize(_depositTokens, address(rewardDistributor));
        rewardTracker.setHandler(address(rewardRouter), true);

        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(4670965608460);

        WBTC(wbtc).approve(address(brrrManager), LARGE_AMOUNT);
        WETH(weth).approve(address(brrrManager), LARGE_AMOUNT);
        Token(usdc).approve(address(brrrManager), LARGE_AMOUNT);
        rewardRouter.mintAndStakeBrrr(weth, DEPOSIT_AMOUNT, 1, 1);
        rewardRouter.mintAndStakeBrrr(wbtc, DEPOSIT_AMOUNT, 1, 1);
        rewardRouter.mintAndStakeBrrr(usdc, DEPOSIT_AMOUNT, 1, 1);

        // CRUCIAL: MUST MINT BRRR VIA ADDING LIQUIDITY BEFORE DIRECT POOL DEPOSITS
        router.directPoolDeposit(weth, SMALL_AMOUNT);
        router.directPoolDeposit(wbtc, SMALL_AMOUNT);
        router.directPoolDeposit(usdc, SMALL_AMOUNT);

        timelock.setShouldToggleIsLeverageEnabled(true);
        timelock.setContractHandler(address(positionRouter), true);
        timelock.setContractHandler(address(positionManager), true);
        timelock.setContractHandler(OWNER, true);
        timelock.setContractHandler(USER, true);

        priceFeedTimelock.setContractHandler(OWNER, true);
        priceFeedTimelock.setContractHandler(USER, true);
        priceFeedTimelock.setKeeper(OWNER, true);

        // Set Gov of all contracts to Timelock
        rewardTracker.setGov(address(timelock));
        rewardDistributor.setGov(address(timelock));
        brrrManager.setGov(address(timelock));
        router.setGov(address(timelock));
        usdp.setGov(address(timelock));
        vaultErrorController.setGov(address(timelock));
        positionRouter.setGov(address(timelock));
        positionManager.setGov(address(timelock));
        orderBook.setGov(address(timelock));
        brrr.setGov(address(timelock));
        rewardRouter.setGov(address(timelock));
        referralStorage.setGov(address(timelock));

        // Set Gov of PriceFeeds to PriceFeedTimelock
        priceFeed.setGov(address(priceFeedTimelock));
        fastPriceFeed.setGov(address(priceFeedTimelock));
        priceEvents.setGov(address(priceFeedTimelock));

        // Set Gov of Shorts Tracker to ShortsTrackerTimelock
        shortsTracker.setGov(address(shortsTrackerTimelock));

        vm.stopPrank();
    }

    modifier giveUserCurrency() {
        vm.deal(OWNER, LARGE_AMOUNT);
        vm.deal(USER, 1e18 ether);
        vm.prank(USER);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        vm.startPrank(OWNER);
        WBTC(wbtc).mint(USER, LARGE_AMOUNT);
        Token(usdc).mint(USER, LARGE_AMOUNT);
        vm.stopPrank();
        _;
    }

    //////////////////
    // Setter tests //
    //////////////////
    function testTimelockSetAdmin() public {
        vm.prank(OWNER);
        timelock.setAdmin(USER);
        assertEq(timelock.admin(), USER);
    }

    function testTimelockSetExternalAdmin() public {
        Timelock newTimelock =
            new Timelock(OWNER, 1, OWNER, OWNER, address(brrrManager), address(rewardRouter), 0, 10, 500);
        vm.prank(OWNER);
        vm.expectRevert();
        timelock.setExternalAdmin(address(newTimelock), USER);
    }

    function testTimelockSetContractHandler() public {
        vm.prank(OWNER);
        timelock.setContractHandler(USER, true);
        assertEq(timelock.isHandler(USER), true);
    }

    function testTimelockInitBrrrManager() public {
        vm.prank(OWNER);
        timelock.initBrrrManager();
        assertEq(timelock.brrrManager(), address(brrrManager));
    }

    function testTimelockInitRewardRouter() public {
        vm.prank(OWNER);
        timelock.initRewardRouter();
        assertEq(timelock.rewardRouter(), address(rewardRouter));
    }

    function testTimelockSetKeeper() public {
        vm.prank(OWNER);
        timelock.setKeeper(USER, true);
        assertEq(timelock.isKeeper(USER), true);
    }

    function testTimelockSetBuffer() public {
        vm.prank(OWNER);
        timelock.setBuffer(100);
        assertEq(timelock.buffer(), 100);
    }

    function testTimelockSetMaxLeverage() public {
        vm.prank(OWNER);
        timelock.setMaxLeverage(address(vault), 1000000);
        assertEq(vault.maxLeverage(), 1000000);
    }

    function testTimelockSetFundingRate() public {
        vm.prank(OWNER);
        timelock.setFundingRate(address(vault), 4600, 50, 50);
        assertEq(vault.fundingInterval(), 4600);
        assertEq(vault.fundingRateFactor(), 50);
        assertEq(vault.stableFundingRateFactor(), 50);
    }

    function testTimelockSetShouldToggleLeverageIsEnabled() public {
        vm.prank(OWNER);
        timelock.setShouldToggleIsLeverageEnabled(false);
        assertEq(timelock.shouldToggleIsLeverageEnabled(), false);
    }

    function testTimelockSetMarginFeeBasisPoints() public {
        vm.prank(OWNER);
        timelock.setMarginFeeBasisPoints(50, 50);
        assertEq(timelock.marginFeeBasisPoints(), 50);
        assertEq(timelock.maxMarginFeeBasisPoints(), 50);
    }

    function testTimelockSetSwapFees() public {
        vm.prank(OWNER);
        timelock.setSwapFees(address(vault), 50, 50, 50, 50, 50);
        assertEq(vault.taxBasisPoints(), 50);
        assertEq(vault.stableTaxBasisPoints(), 50);
        assertEq(vault.mintBurnFeeBasisPoints(), 50);
        assertEq(vault.swapFeeBasisPoints(), 50);
        assertEq(vault.stableSwapFeeBasisPoints(), 50);
    }

    function testTimelockSetFees() public {
        vm.startPrank(OWNER);
        timelock.setMarginFeeBasisPoints(50, 50);
        timelock.setFees(address(vault), 50, 50, 50, 50, 50, 50, 3000000000000000000000000000000, 87000, false);
        vm.stopPrank();
        assertEq(vault.taxBasisPoints(), 50);
        assertEq(vault.stableTaxBasisPoints(), 50);
        assertEq(vault.mintBurnFeeBasisPoints(), 50);
        assertEq(vault.swapFeeBasisPoints(), 50);
        assertEq(vault.stableSwapFeeBasisPoints(), 50);
        assertEq(vault.marginFeeBasisPoints(), 50);
        assertEq(vault.liquidationFeeUsd(), 3000000000000000000000000000000);
        assertEq(vault.minProfitTime(), 87000);
        assertEq(vault.hasDynamicFees(), false);
    }

    function testTimelockEnableAndDisableLeverage() public {
        vm.startPrank(OWNER);
        timelock.enableLeverage(address(vault));
        assertEq(vault.isLeverageEnabled(), true);
        timelock.disableLeverage(address(vault));
        assertEq(vault.isLeverageEnabled(), false);
        vm.stopPrank();
    }

    function testTimelockVaultSetTokenConfig() public {
        vm.startPrank(OWNER);
        Token newUsdc = new Token();
        // Set Up Price Feed for Token
        priceFeedTimelock.signalPriceFeedSetTokenConfig(address(priceFeed), address(newUsdc), usdcPriceFeed, 8, true);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        priceFeedTimelock.priceFeedSetTokenConfig(address(priceFeed), address(newUsdc), usdcPriceFeed, 8, true);
        assertGt(priceFeed.getPrimaryPrice(address(newUsdc), true), 0);
        // Set Up Token Config
        timelock.signalVaultSetTokenConfig(address(vault), address(newUsdc), 6, 20000, 150, 1e20, true, false);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        timelock.vaultSetTokenConfig(address(vault), address(newUsdc), 6, 20000, 150, 1e20, true, false);
        vm.stopPrank();
        assertEq(vault.whitelistedTokens(address(newUsdc)), true);
    }

    function testTimelockSetUsdpAmounts() public {
        vm.startPrank(OWNER);
        wethArray.push(weth);
        address[] memory _wethArray = wethArray;
        numberArray.push(1);
        uint256[] memory _amounts = numberArray;
        timelock.setUsdpAmounts(address(vault), _wethArray, _amounts);
        vm.stopPrank();
        assertEq(vault.usdpAmounts(weth), 1);
    }

    // Fuzzed because why not :)
    function testTimelockUpdateUsdpSupply(uint256 _amount) public {
        vm.startPrank(OWNER);
        timelock.updateUsdpSupply(_amount);
        vm.stopPrank();
    }

    function testTimelockSetShortsTrackerAveragePriceWeight(uint256 _priceWeight) public {
        vm.startPrank(OWNER);
        timelock.setShortsTrackerAveragePriceWeight(_priceWeight);
        vm.stopPrank();
    }

    function testTimelockSetBrrrCooldownDuration() public {
        vm.startPrank(OWNER);
        timelock.setBrrrCooldownDuration(1 hours);
        vm.stopPrank();
    }

    function testTimelockSetMaxGlobalShortSize(uint256 _amount) public {
        vm.startPrank(OWNER);
        timelock.setMaxGlobalShortSize(address(vault), wbtc, _amount);
        vm.stopPrank();
    }

    function testTimelockLetsUsRemoveAnAdminFromYieldTokens() public {
        vm.prank(address(timelock));
        usdp.addAdmin(USER);
        vm.prank(OWNER);
        timelock.removeAdmin(address(usdp), USER);
        assertEq(usdp.admins(USER), false);
    }

    function testTimelockSetIsSwapEnabled() public {
        vm.startPrank(OWNER);
        timelock.setIsSwapEnabled(address(vault), false);
        vm.stopPrank();
        assertEq(vault.isSwapEnabled(), false);
    }

    function testTimelockSetTierForReferrals() public {
        vm.startPrank(OWNER);
        timelock.setTier(address(referralStorage), 4, 5000, 5000);
        vm.stopPrank();
    }

    function testTimelockSetReferrerTier() public {
        vm.startPrank(OWNER);
        timelock.setReferrerTier(address(referralStorage), USER, 2);
        vm.stopPrank();
        assertEq(referralStorage.referrerTiers(USER), 2);
    }

    function testTimelockReferralGovSetCodeOwner() public {
        bytes32 randomCode = keccak256(abi.encodePacked("RandomCode"));
        vm.startPrank(OWNER);
        timelock.govSetCodeOwner(address(referralStorage), randomCode, USER);
        vm.stopPrank();
        assertEq(referralStorage.codeOwners(randomCode), USER);
    }

    function testTimelockSetVaultUtils() public {
        VaultUtils newVaultUtils = new VaultUtils(vault);
        vm.startPrank(OWNER);
        timelock.setVaultUtils(address(vault), newVaultUtils);
        vm.stopPrank();
        assertEq(address(vault.vaultUtils()), address(newVaultUtils));
    }

    function testTimelockSetMaxGasPrice() public {
        vm.startPrank(OWNER);
        timelock.setMaxGasPrice(address(vault), 6000000000);
        vm.stopPrank();
        assertEq(vault.maxGasPrice(), 6000000000);
    }

    function testTimelockSetInPrivateLiquidationMode() public {
        vm.startPrank(OWNER);
        timelock.setInPrivateLiquidationMode(address(vault), true);
        assertEq(vault.inPrivateLiquidationMode(), true);
        timelock.setInPrivateLiquidationMode(address(vault), false);
        assertEq(vault.inPrivateLiquidationMode(), false);
        vm.stopPrank();
    }

    function testTimelockSetLiquidator() public {
        vm.startPrank(OWNER);
        timelock.setLiquidator(address(vault), USER, true);
        vm.stopPrank();
        assertEq(vault.isLiquidator(USER), true);
    }

    function testTimelockSetInPrivateTransferMode() public {
        vm.startPrank(OWNER);
        timelock.setInPrivateTransferMode(address(brrr), true);
        vm.stopPrank();
        assertEq(brrr.inPrivateTransferMode(), true);
    }

    //////////////////
    // Getter Tests //
    //////////////////

    ////////////////////
    // Function Tests //
    ////////////////////

    function testTimelockWithdrawFees() public {
        vm.startPrank(OWNER);
        timelock.withdrawFees(address(vault), weth, OWNER);
        vm.stopPrank();
    }

    function testTimelockBatchWithdrawFees() public {
        vm.startPrank(OWNER);
        tokenArray.push(usdc);
        address[] memory _tokens = tokenArray;
        timelock.batchWithdrawFees(address(vault), _tokens);
        vm.stopPrank();
    }

    function testTimelockTransferIn() public {
        vm.startPrank(OWNER);
        WETH(weth).approve(address(timelock), LARGE_AMOUNT);
        timelock.transferIn(OWNER, weth, 1e18);
        vm.stopPrank();
        assertEq(WETH(weth).balanceOf(address(timelock)), 1e18);
    }

    function testTimelockSignalApproveAndApprove() public {
        vm.startPrank(OWNER);
        WETH(weth).approve(address(timelock), LARGE_AMOUNT);
        timelock.transferIn(OWNER, weth, 1e18);
        timelock.signalApprove(weth, OWNER, 1e18);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.approve(weth, OWNER, 1e18);
        WETH(weth).transferFrom(address(timelock), OWNER, 1e18);
        assertEq(WETH(weth).balanceOf(address(timelock)), 0);
        vm.stopPrank();
    }

    // Withdraw from Base token e.g BRRR
    function testTimelockSignalWithdrawAndWithdraw() public {
        vm.startPrank(OWNER);
        WETH(weth).transfer(address(brrr), 1e18);
        timelock.signalWithdrawToken(address(brrr), weth, OWNER, 1e18);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.withdrawToken(address(brrr), weth, OWNER, 1e18);
        assertEq(WETH(weth).balanceOf(address(brrr)), 0);
        vm.stopPrank();
    }

    function testTimelockSignalMintAndProcessMint() public {
        uint256 brrrBalBefore = brrr.balanceOf(OWNER);
        vm.startPrank(OWNER);
        timelock.signalMint(address(brrr), OWNER, 1e18);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.processMint(address(brrr), OWNER, 1e18);
        vm.stopPrank();
        uint256 brrrBalAfter = brrr.balanceOf(OWNER);
        assertEq(brrrBalAfter - brrrBalBefore, 1e18);
    }

    function testTimelockSignalAndSetGov() public {
        vm.startPrank(OWNER);
        timelock.signalSetGov(address(vault), USER);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.setGov(address(vault), USER);
        vm.stopPrank();
        assertEq(vault.gov(), USER);
    }

    function testTimelockSignalAndSetHandler() public {
        vm.startPrank(OWNER);
        timelock.signalSetHandler(address(brrrManager), USER, true);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.setHandler(address(brrrManager), USER, true);
        vm.stopPrank();
        assertEq(brrrManager.isHandler(USER), true);
    }

    function testTimelockSignalAndSetPriceFeed() public {
        VaultPriceFeed newPriceFeed = new VaultPriceFeed();
        vm.startPrank(OWNER);
        timelock.signalSetPriceFeed(address(vault), address(newPriceFeed));
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.setPriceFeed(address(vault), address(newPriceFeed));
        vm.stopPrank();
        assertEq(vault.priceFeed(), address(newPriceFeed));
    }

    function testTimelockSignalAndRedeemUsdp() public {
        vm.startPrank(OWNER);
        timelock.signalRedeemUsdp(address(vault), weth, 1e18);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.redeemUsdp(address(vault), weth, 1e18);
        vm.stopPrank();
    }

    function testTimelockSignalAndClearTokenConfig() public {
        vm.startPrank(OWNER);
        timelock.signalVaultClearTokenConfig(address(vault), usdc);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        timelock.vaultClearTokenConfig(address(vault), usdc);
        vm.stopPrank();
        assertEq(vault.whitelistedTokens(usdc), false);
    }

    function testTimelockCancelAction() public {
        vm.startPrank(OWNER);
        timelock.signalVaultClearTokenConfig(address(vault), wbtc);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        bytes32 action = keccak256(abi.encodePacked("vaultClearTokenConfig", address(vault), wbtc));
        timelock.cancelAction(action);
        assertEq(timelock.pendingActions(action), 0);
    }
}
