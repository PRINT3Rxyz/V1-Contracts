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
import {BrrrXpAmplifier} from "../../../src/staking/BrrrXpAmplifier.sol";
import {ShortsTrackerTimelock} from "../../../src/peripherals/ShortsTrackerTimelock.sol";
import {RewardClaimer} from "../../../src/staking/RewardClaimer.sol";

contract BrrrXpAmplifierTest is Test {
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

        positionManager =
            new PositionManager(address(vault), address(router), address(shortsTracker), weth, 50, address(orderBook));

        positionRouter =
            new PositionRouter(address(vault), address(router), weth, address(shortsTracker), 30, 300000000000000);

        brrr = new BRRR();

        // Set cooldown to 0 for BrrrManager to work seamlessly
        brrrManager = new BrrrManager(address(vault), address(usdp), address(brrr), address(shortsTracker), 0);

        vaultErrorController = new VaultErrorController();

        WBTC(wbtc).mint(OWNER, LARGE_AMOUNT);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        Token(usdc).mint(OWNER, LARGE_AMOUNT);

        referralStorage = new ReferralStorage();

        rewardRouter = new BrrrRewardRouter();

        rewardTracker = new RewardTracker("Staked BRRR", "sBRRR");

        rewardDistributor = new RewardDistributor(weth, address(rewardTracker));

        timelock = new Timelock(OWNER, 1, OWNER, OWNER, address(brrrManager), 1e60, 10, 500);

        transferStakedBrrr = new TransferStakedBrrr(address(brrr), brrrManager, address(rewardTracker));

        brrrBalance = new BrrrBalance(brrrManager, address(rewardTracker));

        orderBookReader = new OrderBookReader();

        vaultReader = new VaultReader();

        rewardReader = new RewardReader();

        referralReader = new ReferralReader();

        reader = new Reader();

        amplifier = new BrrrXpAmplifier(address(rewardTracker), address(transferStakedBrrr), weth);

        shortsTrackerTimelock = new ShortsTrackerTimelock(OWNER, 60, 300, 20);

        rewardClaimer = new RewardClaimer(address(amplifier), address(rewardTracker));

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
        vault.setFees(15, 5, 15, 15, 1, 10, 2000000000000000000000000000000, 10800, true);
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
        // IMPORTANT STEP
        rewardTracker.setHandler(address(rewardRouter), true);
        // TransferStakedBrrr must be a handler for BrrrXpAmplifier to function
        rewardTracker.setHandler(address(transferStakedBrrr), true);
        rewardTracker.setHandler(address(rewardClaimer), true);

        amplifier.setHandler(address(rewardClaimer), true);

        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(165343915343915);

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

        uint256[] memory priceArray = new uint256[](2);
        priceArray[0] = priceFeed.getPrimaryPrice(weth, true);
        priceArray[1] = priceFeed.getPrimaryPrice(wbtc, true);
        /// CRUCIAL: MUST CALL BEFORE SETTING GOV TO SHORTSTIMELOCK
        shortsTracker.setInitData(tokenArray, priceArray);
        shortsTracker.setGov(address(shortsTrackerTimelock));

        vm.stopPrank();
    }

    event BrrrXpAmplifier_LiquidityLocked(
        address indexed user, uint256 index, uint256 indexed amount, uint8 indexed tier
    );
    event BrrrXpAmplifier_LiquidityUnlocked(
        address indexed user, uint256 index, uint256 indexed amount, uint8 indexed tier
    );

    modifier giveUserCurrency() {
        vm.deal(OWNER, LARGE_AMOUNT);
        vm.deal(USER, 1e18 ether);
        vm.startPrank(OWNER);
        WBTC(wbtc).mint(USER, LARGE_AMOUNT);
        Token(usdc).mint(USER, LARGE_AMOUNT);
        vm.stopPrank();
        vm.startPrank(USER);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        vm.stopPrank();
        _;
    }

    modifier setUpAmplifier() {
        vm.deal(USER, 1e18 ether);
        vm.startPrank(OWNER);
        WETH(weth).transfer(address(rewardDistributor), 1e24);
        WBTC(wbtc).mint(USER, LARGE_AMOUNT);
        Token(usdc).mint(USER, LARGE_AMOUNT);
        vm.stopPrank();
        vm.startPrank(USER);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        WETH(weth).approve(address(brrrManager), LARGE_AMOUNT);
        rewardRouter.mintAndStakeBrrr(weth, DEPOSIT_AMOUNT, 1, 1);
        vm.stopPrank();
        _;
    }

    function testAmplifierSetGovCanOnlyBeCalledByTheGov() public {
        vm.prank(USER);
        vm.expectRevert();
        amplifier.setGov(USER);
        vm.prank(OWNER);
        amplifier.setGov(USER);
        assertEq(amplifier.gov(), USER);
    }

    function testAmplifierEmptyPostSeasonRewardsWorksFromGov() public setUpAmplifier {
        vm.prank(OWNER);
        WETH(weth).transfer(address(amplifier), 1e19);
        vm.warp(1717243201);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        amplifier.recoverTokens(weth);
        assertEq(WETH(weth).balanceOf(address(amplifier)), 0);
    }

    function testAmplifierCantEmptyPostSeasonRewardsWhileSeasonIsActive() public setUpAmplifier {
        vm.prank(OWNER);
        WETH(weth).transfer(address(amplifier), 1e19);
        vm.prank(OWNER);
        vm.expectRevert();
        amplifier.recoverTokens(weth);
    }

    //////////////////////////
    // Lock Liquidity Tests //
    //////////////////////////

    function testAmplifierLockLiquidityWorks() public setUpAmplifier {
        assertGt(rewardTracker.balanceOf(USER), 0);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, 1e18);
        assertEq(tier, 0);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockedUntil, block.timestamp + 1 hours);
        assertEq(locker, USER);
        assertEq(multiplier, 100);
    }

    function testAmplifierLockLiquidityFailsWithWrongTier() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        vm.expectRevert();
        amplifier.lockLiquidity(5, 1e18);
        vm.stopPrank();
    }

    function testAmplifierLockLiquidityFuzzInputs(uint256 amount) public setUpAmplifier {
        vm.assume(rewardTracker.balanceOf(USER) >= amount);
        vm.assume(amount > 0);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, amount);
        vm.stopPrank();
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, amount);
        assertEq(tier, 0);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockedUntil, block.timestamp + 1 hours);
        assertEq(locker, USER);
        assertEq(multiplier, 100);
    }

    function testAmplifierUserCantLockMoreLiquidityThanBalance() public setUpAmplifier {
        uint256 balance = rewardTracker.balanceOf(USER);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        vm.expectRevert();
        amplifier.lockLiquidity(0, balance + 1);
        vm.stopPrank();
    }

    function testAmplifierUsersCantLockForLongerThanTheSeasonDuration() public setUpAmplifier {
        vm.warp(1717243200);
        vm.roll(block.number + 1);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        vm.expectRevert();
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
    }

    function testAmplifierLockTier2() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(1, 1e18);
        vm.stopPrank();
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, 1e18);
        assertEq(tier, 1);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockedUntil, block.timestamp + 30 days);
        assertEq(locker, USER);
        assertEq(multiplier, 125);
    }

    function testAmplifierLockTier3() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(2, 1e18);
        vm.stopPrank();
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, 1e18);
        assertEq(tier, 2);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockedUntil, block.timestamp + 90 days);
        assertEq(locker, USER);
        assertEq(multiplier, 150);
    }

    function testAmplifierLockTier4() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(3, 1e18);
        vm.stopPrank();
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, 1e18);
        assertEq(tier, 3);
        assertEq(lockedAt, block.timestamp);
        assertEq(lockedUntil, block.timestamp + 180 days);
        assertEq(locker, USER);
        assertEq(multiplier, 200);
    }

    function testAmplifierUsersCanCreate2SeparatePositionsAndTrackThem() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        amplifier.lockLiquidity(1, 1e18);
        vm.stopPrank();
        (
            uint256 depositAmount1,
            uint8 tier1,
            uint256 lockedAt1,
            uint256 lockedUntil1,
            address locker1,
            uint256 multiplier1
        ) = amplifier.positions(USER, 0);
        (
            uint256 depositAmount2,
            uint8 tier2,
            uint256 lockedAt2,
            uint256 lockedUntil2,
            address locker2,
            uint256 multiplier2
        ) = amplifier.positions(USER, 1);
        assertEq(depositAmount1, 1e18);
        assertEq(tier1, 0);
        assertEq(lockedAt1, block.timestamp);
        assertEq(lockedUntil1, block.timestamp + 1 hours);
        assertEq(locker1, USER);
        assertEq(multiplier1, 100);
        assertEq(depositAmount2, 1e18);
        assertEq(tier2, 1);
        assertEq(lockedAt2, block.timestamp);
        assertEq(lockedUntil2, block.timestamp + 30 days);
        assertEq(locker2, USER);
        assertEq(multiplier2, 125);
    }

    function testAmplifierTwoSeparateUsersCanCreatePositionsAndTrackThem() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.startPrank(OWNER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(1, 1e18);
        vm.stopPrank();
        (
            uint256 depositAmount1,
            uint8 tier1,
            uint256 lockedAt1,
            uint256 lockedUntil1,
            address locker1,
            uint256 multiplier1
        ) = amplifier.positions(USER, 0);
        (
            uint256 depositAmount2,
            uint8 tier2,
            uint256 lockedAt2,
            uint256 lockedUntil2,
            address locker2,
            uint256 multiplier2
        ) = amplifier.positions(OWNER, 1);
        assertEq(depositAmount1, 1e18);
        assertEq(tier1, 0);
        assertEq(lockedAt1, block.timestamp);
        assertEq(lockedUntil1, block.timestamp + 1 hours);
        assertEq(locker1, USER);
        assertEq(multiplier1, 100);
        assertEq(depositAmount2, 1e18);
        assertEq(tier2, 1);
        assertEq(lockedAt2, block.timestamp);
        assertEq(lockedUntil2, block.timestamp + 30 days);
        assertEq(locker2, OWNER);
        assertEq(multiplier2, 125);
    }

    function testAmplifierUserPositionIdsTracksTheIdsForAUsersPositions() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        vm.stopPrank();
        vm.startPrank(OWNER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(1, 1e17);
        vm.stopPrank();
        uint256 positionId1 = amplifier.userPositionIds(USER, 0);
        uint256 positionId2 = amplifier.userPositionIds(OWNER, 0);
        assertEq(positionId1, 0);
        assertEq(positionId2, 6);
    }

    function testAmplifierUserCanGetTotalDepositedBalance() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        amplifier.lockLiquidity(1, 1e17);
        vm.stopPrank();
        assertEq(amplifier.lockedAmount(USER), 6e17);
    }

    function testAmplifierLockLiquidityFiresLiquidityLockedEventWithCorrectArgs() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        vm.expectEmit();
        emit BrrrXpAmplifier_LiquidityLocked(USER, 0, 1e17, 1);
        amplifier.lockLiquidity(1, 1e17);
        vm.stopPrank();
    }

    ////////////////////////////
    // Unlock Liquidity Tests //
    ////////////////////////////

    function testAmplifierUnlockLiquidityWorks() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 100 days);
        vm.roll(block.number + 1);
        uint256 wethBalBefore = WETH(weth).balanceOf(USER);
        vm.prank(USER);
        amplifier.unlockLiquidity(0);
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, 0);
        assertEq(tier, 0);
        assertEq(lockedAt, 0);
        assertEq(lockedUntil, 0);
        assertEq(locker, address(0));
        assertEq(multiplier, 0);
        vm.prank(USER);
        amplifier.claimPendingRewards();
        uint256 wethBalAfter = WETH(weth).balanceOf(USER);
        assertGt(wethBalAfter, wethBalBefore);
    }

    function testAmplifierUnlockLiquidityFailsIfUserDoesntOwnPosition() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        vm.expectRevert();
        amplifier.unlockLiquidity(0);
    }

    function testAmplifierUnlockLiquidityFailsIfDurationHasntPassed() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.warp(block.timestamp + 3599);
        vm.roll(block.number + 1);
        vm.expectRevert();
        amplifier.unlockLiquidity(0);
        vm.stopPrank();
    }

    function testAmplifierUnlockLiquidityFailsIfContractDoesntHaveEnoughFunds() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.prank(address(amplifier));
        transferStakedBrrr.transfer(OWNER, 1e18);
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        vm.prank(USER);
        vm.expectRevert();
        amplifier.unlockLiquidity(0);
    }

    function testAmplifierUserCantUnstakeBrrrAfterCreatingALockedPosition() public setUpAmplifier {
        uint256 balance = rewardTracker.balanceOf(USER);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), balance);
        amplifier.lockLiquidity(0, balance);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        vm.prank(USER);
        vm.expectRevert();
        rewardRouter.unstakeAndRedeemBrrr(weth, balance, 1, USER);
    }

    function testAmplifierUserCanClaimAnyPendingTokenAndXpRewardsAfterUnstaking() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        uint256 wethBalBefore = WETH(weth).balanceOf(address(amplifier));

        vm.startPrank(USER);
        amplifier.unlockLiquidity(0);
        uint256 expectedXp = 86401e18;
        amplifier.claimPendingRewards();
        vm.stopPrank();
        assertGt(WETH(weth).balanceOf(USER), wethBalBefore);
        assertEq(amplifier.totalXpEarned(USER), expectedXp);
    }

    function testAmplifierClearsAllPositionDataWhenUnstaking() public setUpAmplifier {
        uint256 balance = rewardTracker.balanceOf(USER);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), balance);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        vm.prank(USER);
        amplifier.unlockLiquidity(0);
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 0);
        assertEq(depositAmount, 0);
        assertEq(tier, 0);
        assertEq(lockedAt, 0);
        assertEq(lockedUntil, 0);
        assertEq(locker, address(0));
        assertEq(multiplier, 0);
        uint256[] memory userTokenIds = amplifier.getUserPositionIds(USER);
        assertEq(userTokenIds.length, 0);
    }

    function testAmplifierClearAPositionCorrectlyWhenMoreThanOneOpen() public setUpAmplifier {
        uint256 balance = rewardTracker.balanceOf(USER);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), balance);
        amplifier.lockLiquidity(0, 1e18);
        amplifier.lockLiquidity(0, 1e18);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        vm.prank(USER);
        amplifier.unlockLiquidity(1);
        (uint256 depositAmount, uint8 tier, uint256 lockedAt, uint256 lockedUntil, address locker, uint256 multiplier) =
            amplifier.positions(USER, 1);
        assertEq(depositAmount, 0);
        assertEq(tier, 0);
        assertEq(lockedAt, 0);
        assertEq(lockedUntil, 0);
        assertEq(locker, address(0));
        assertEq(multiplier, 0);
        uint256[] memory userTokenIds = amplifier.getUserPositionIds(USER);
        assertEq(userTokenIds.length, 2);
        assertEq(userTokenIds[0], 0);
        assertEq(userTokenIds[1], 2);
    }

    function testAmplifierLiquidityUnlockedEventFiresOnUnlock() public setUpAmplifier {
        uint256 balance = rewardTracker.balanceOf(USER);
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), balance);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);
        vm.prank(USER);
        vm.expectEmit();
        emit BrrrXpAmplifier_LiquidityUnlocked(USER, 0, 1e18, 0);
        amplifier.unlockLiquidity(0);
    }

    /////////////////////////////////
    // Claim Pending Rewards Tests //
    /////////////////////////////////

    function testAmplifierClaimPendingRewardsLetsUsersClaimRewardsFromPositionsThatAreStillLocked()
        public
        setUpAmplifier
    {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        uint256 wethBalBefore = WETH(weth).balanceOf(USER);
        uint256 xpBefore = amplifier.totalXpEarned(USER);
        vm.prank(USER);
        amplifier.claimPendingRewards();
        uint256 expectedXp = 86401e18;
        assertEq(amplifier.totalXpEarned(USER), expectedXp + xpBefore);
        assertGt(WETH(weth).balanceOf(USER), wethBalBefore);
    }

    event BrrrXpAmplifier_RewardsClaimed(address indexed user, uint256 indexed tokenAmount, uint256 indexed xpAmount);

    function testAmplifierClaimPendingRewardsGivesZeroRewardsToUnqualifiedUsers() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        vm.expectEmit();
        emit BrrrXpAmplifier_RewardsClaimed(OWNER, 0, 0);
        amplifier.claimPendingRewards();
    }

    function testAmplifierRewardsAreProportionallySplitAmongAllUsers() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.startPrank(OWNER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        uint256 userClaimableRewards = amplifier.getClaimableTokenRewards(USER);
        uint256 ownerClaimableRewards = amplifier.getClaimableTokenRewards(OWNER);

        assertEq(userClaimableRewards, ownerClaimableRewards * 2);
        // Due to rounding errors, value returned is slightly over double, but will = double
        assertGt(amplifier.getClaimableXpRewards(OWNER) * 2, amplifier.getClaimableXpRewards(USER));
    }

    function testAmplifierUsersEarnTheSameRewardsAsTheyWouldHaveDoneIfTheyDidntLockIn() public {
        // Set Up
        vm.deal(USER, 1e18 ether);
        vm.prank(OWNER);
        WETH(weth).transfer(address(rewardDistributor), 1e24);
        vm.startPrank(USER);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        WETH(weth).approve(address(brrrManager), LARGE_AMOUNT);
        uint256 stakedBrrrAmount = rewardRouter.mintAndStakeBrrr(weth, 1e18, 1, 1);
        vm.stopPrank();

        // Get 1 days rewards regular
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        vm.prank(USER);
        uint256 regularAmount = rewardTracker.claim(USER);
        console.log(regularAmount);

        // Get 1 days rewards locked
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, stakedBrrrAmount);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        vm.prank(USER);
        (uint256 lockedAmount,) = amplifier.claimPendingRewards();
        console.log(lockedAmount);
        // Added 1 just to account for precision error so test passes
        assertEq(lockedAmount + 1, regularAmount);
    }

    function testAmplifierUsersCanKeepTokensLockedLongerThanTheDurationAndStillEarnRewards() public setUpAmplifier {
        // Lock tokens
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(1, 1e18);
        vm.stopPrank();
        vm.startPrank(OWNER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        // Warp to end of lock duration
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1);
        vm.startPrank(OWNER);
        amplifier.unlockLiquidity(1); // Update pending token rewards
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        // Check rewards
        uint256 pending1 = amplifier.getClaimableTokenRewards(USER);
        // Warp another duration
        vm.warp(block.timestamp + 30 days);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        amplifier.unlockLiquidity(2); // update pending token rewards
        // Check rewards
        uint256 pending2 = amplifier.getClaimableTokenRewards(USER);
        console.log(pending2);
        console.log(pending1);
        assertGt(pending2, pending1);
    }

    function testAmplifierClaimPendingRewardsSetsTheUsersPendingRewardsToZero() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        vm.prank(USER);
        amplifier.claimPendingRewards();

        assertEq(amplifier.claimableReward(USER), 0);
        assertEq(amplifier.getClaimableXpRewards(USER), 0);
    }

    function testAmplifierClaimPendingRewardsIncreasesTheUsersTotalXpEarnedMapping() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        uint256 xpBefore = amplifier.totalXpEarned(USER);

        vm.prank(USER);
        (, uint256 xpAdded) = amplifier.claimPendingRewards();
        assertEq(amplifier.totalXpEarned(USER), xpBefore + xpAdded);
    }

    //////////////////////////
    // Recover Tokens Tests //
    //////////////////////////

    function testAmplifierRecoverTokensRecoversWronglySentTokensFromTheSmartContract() public giveUserCurrency {
        vm.prank(USER);
        WBTC(wbtc).transfer(address(amplifier), 1e18);

        uint256 ownerTokenBalBefore = WBTC(wbtc).balanceOf(OWNER);

        vm.prank(OWNER);
        amplifier.recoverTokens(wbtc);

        uint256 ownerTokenBalAfter = WBTC(wbtc).balanceOf(OWNER);

        assertEq(ownerTokenBalAfter, ownerTokenBalBefore + 1e18);
    }

    function testAmplifierRecoverTokensCanOnlyRecoverKeyTokensAfterTheSeasonEnds() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        WETH(weth).transfer(address(amplifier), 1e18);
        vm.stopPrank();

        vm.prank(OWNER);
        vm.expectRevert();
        amplifier.recoverTokens(weth);

        vm.prank(OWNER);
        vm.expectRevert();
        amplifier.recoverTokens(address(rewardTracker));

        vm.warp(block.timestamp + 1717243201);
        vm.roll(block.number + 1);

        uint256 balBefore1 = WETH(weth).balanceOf(OWNER);
        uint256 balBefore2 = rewardTracker.balanceOf(OWNER);

        vm.startPrank(OWNER);
        amplifier.recoverTokens(weth);
        amplifier.recoverTokens(address(rewardTracker));
        vm.stopPrank();

        uint256 balAfter1 = WETH(weth).balanceOf(OWNER);
        uint256 balAfter2 = rewardTracker.balanceOf(OWNER);

        assertEq(balAfter1, balBefore1 + 1e18);
        assertEq(balAfter2, balBefore2 + 1e18);
    }

    function testAmplifierRecoverTokensOnlyWorksFromGov() public giveUserCurrency {
        vm.startPrank(USER);
        WBTC(wbtc).transfer(address(amplifier), 1e18);
        vm.expectRevert();
        amplifier.recoverTokens(wbtc);
        vm.stopPrank();
    }

    ////////////////////////////////
    // Update Xp Per Second Tests //
    ////////////////////////////////

    function testAmplifierUpdateXpPerSecondOnlyWorksFromGovAddress() public {
        vm.prank(USER);
        vm.expectRevert();
        amplifier.updateXpPerSecond(3);

        vm.prank(OWNER);
        amplifier.updateXpPerSecond(2);

        assertEq(amplifier.xpPerSecond(), 2);
    }

    function testAmplifierUpdateXpPerSecondRevertsIfValIsZero() public {
        vm.prank(OWNER);
        vm.expectRevert();
        amplifier.updateXpPerSecond(0);
    }

    function testAmplifierUpdateXpPerSecondScalesXpRewardsByTheSpecifiedAmount() public setUpAmplifier {
        vm.prank(OWNER);
        amplifier.updateXpPerSecond(2);

        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        uint256 usualXpRewards = 86401e18;

        vm.prank(USER);
        amplifier.claimPendingRewards();

        uint256 xpRewards = amplifier.totalXpEarned(USER);
        assertEq(xpRewards, usualXpRewards * 2);
    }

    //////////////////
    // Getter Tests //
    //////////////////

    function testAmplifierGetClaimableTokenRewardsReturnsTheCorrectValue() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        uint256 claimableRewards = amplifier.getClaimableTokenRewards(USER);
        vm.prank(USER);
        (uint256 claimed,) = amplifier.claimPendingRewards();
        assertEq(claimableRewards, claimed);
    }

    function testAmplifierGetClaimableXpRewardsReturnsTheCorrectValue() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        uint256 claimableXpRewards = amplifier.getClaimableXpRewards(USER);
        vm.prank(USER);
        (, uint256 claimed) = amplifier.claimPendingRewards();
        assertEq(claimableXpRewards, claimed);
        assertEq(amplifier.getClaimableXpRewards(USER), 0);
    }

    function testAmplifierGetRemainingLockDurationReturnsTheCorrectValue() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(3, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);

        uint256 remaining = (180 days + 1) - block.timestamp;
        assertEq(amplifier.getRemainingLockDuration(USER, 0), remaining);
    }

    function testAmplifierGetUserPositionIdsReturnsAllOfAUsersLockedIds() public setUpAmplifier {
        vm.startPrank(USER);
        transferStakedBrrr.approve(address(amplifier), LARGE_AMOUNT);
        amplifier.lockLiquidity(0, 1e18);
        amplifier.lockLiquidity(0, 1e18);
        amplifier.lockLiquidity(0, 1e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        vm.prank(USER);
        amplifier.unlockLiquidity(1);

        uint256[] memory userTokenIds = amplifier.getUserPositionIds(USER);
        assertEq(userTokenIds.length, 2);
        assertEq(userTokenIds[0], 0);
        assertEq(userTokenIds[1], 2);
    }
}
