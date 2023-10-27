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
import {PriceFeedTimelock} from "../../../src/peripherals/PriceFeedTimelock.sol";
import {RewardTimelock} from "../../../src/peripherals/RewardTimelock.sol";

contract RewardTimelockTest is Test {
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
    PriceFeedTimelock priceFeedTimelock;
    RewardTimelock rewardTimelock;

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

        priceFeedTimelock = new PriceFeedTimelock(OWNER, 1, OWNER);

        rewardTimelock =
            new RewardTimelock(OWNER, 1, OWNER, address(rewardRouter), address(brrrManager), address(rewardDistributor));

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

        // Set Governance
        shortsTracker.setGov(address(shortsTrackerTimelock));
        priceFeed.setGov(address(priceFeedTimelock));
        usdp.setGov(address(timelock));
        positionManager.setGov(address(timelock));
        positionRouter.setGov(address(timelock));
        brrr.setGov(address(timelock));
        brrrManager.setGov(address(timelock));
        vaultErrorController.setGov(address(timelock));
        referralStorage.setGov(address(timelock));
        rewardDistributor.setGov(address(rewardTimelock));
        rewardTracker.setGov(address(rewardTimelock));
        rewardRouter.setGov(address(rewardTimelock));
        amplifier.setGov(address(rewardTimelock));

        vm.stopPrank();
    }

    modifier giveUserCurrency() {
        vm.deal(OWNER, LARGE_AMOUNT);
        vm.deal(USER, 1e18 ether);
        vm.startPrank(OWNER);
        WBTC(wbtc).mint(USER, LARGE_AMOUNT);
        Token(usdc).mint(USER, LARGE_AMOUNT);
        vm.stopPrank();
        vm.startPrank(USER);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        WETH(weth).transfer(address(rewardDistributor), 100e18);
        vm.stopPrank();
        _;
    }

    function testRewardTimelockSetAdmin() public {
        vm.prank(OWNER);
        rewardTimelock.setAdmin(USER);
        assertEq(rewardTimelock.admin(), USER);
    }

    function testRewardTimelockSetTokenManager() public {
        vm.prank(OWNER);
        rewardTimelock.setTokenManager(USER);
        assertEq(rewardTimelock.tokenManager(), USER);
    }

    function testRewardTimelockSetContractHandler() public {
        vm.prank(OWNER);
        rewardTimelock.setContractHandler(USER, true);
        assertEq(rewardTimelock.isHandler(USER), true);
    }

    function testRewardTimelockSetKeeper() public {
        vm.prank(OWNER);
        rewardTimelock.setKeeper(USER, true);
        assertEq(rewardTimelock.isKeeper(USER), true);
    }

    function testRewardTimelockSetBufferCanOnlyIncrease() public {
        vm.prank(OWNER);
        vm.expectRevert();
        rewardTimelock.setBuffer(0);
    }

    function testRewardTimelockSetBufferCanIncrease() public {
        vm.prank(OWNER);
        rewardTimelock.setBuffer(2);
        assertEq(rewardTimelock.buffer(), 2);
    }

    function testRewardTimelockTransferIn() public {
        vm.startPrank(OWNER);
        WETH(weth).approve(address(rewardTimelock), 1e18);
        rewardTimelock.transferIn(OWNER, weth, 1e18);
        assertEq(WETH(weth).balanceOf(address(rewardTimelock)), 1e18);
    }

    function testRewardTimelockApprove() public {
        vm.startPrank(OWNER);
        WETH(weth).approve(address(rewardTimelock), 1e18);
        rewardTimelock.transferIn(OWNER, weth, 1e18);
        rewardTimelock.signalApprove(weth, OWNER, 1e18);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        rewardTimelock.approve(weth, OWNER, 1e18);
        WETH(weth).transferFrom(address(rewardTimelock), OWNER, 1e18);
        vm.stopPrank();
    }

    function testRewardTimelockSetGov() public {
        vm.startPrank(OWNER);
        rewardTimelock.signalSetGov(address(rewardRouter), USER);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        rewardTimelock.setGov(address(rewardRouter), USER);
        vm.stopPrank();
        assertEq(rewardRouter.gov(), USER);
    }

    function testRewardTimelockSetHandler() public {
        vm.startPrank(OWNER);
        rewardTimelock.signalSetHandler(address(rewardTracker), OWNER, true);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        rewardTimelock.setHandler(address(rewardTracker), OWNER, true);
        vm.stopPrank();
        assertEq(rewardTracker.isHandler(OWNER), true);
    }

    function testRewardTimelockRecoverTokens() public {
        vm.startPrank(OWNER);
        WETH(weth).transfer(address(amplifier), 1e18);
        rewardTimelock.signalRecoverTokens(weth, address(amplifier));
        vm.warp(block.timestamp + 1717243201);
        vm.roll(block.number + 1);
        rewardTimelock.recoverTokens(weth, address(amplifier));
        vm.stopPrank();
        assertEq(WETH(weth).balanceOf(address(rewardTimelock)), 1e18);
    }

    function testRewardTimelockUpdateXpPerSecond() public {
        vm.startPrank(OWNER);
        rewardTimelock.signalUpdateXpPerSecond(2, address(amplifier));
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        rewardTimelock.updateXpPerSecond(2, address(amplifier));
        vm.stopPrank();
        assertEq(amplifier.xpPerSecond(), 2);
    }

    function testRewardTimelockSetDistributorRewards() public {
        vm.startPrank(OWNER);
        WETH(weth).transfer(address(rewardDistributor), SMALL_AMOUNT);
        uint256 tokensPerInterval = SMALL_AMOUNT / 604800;
        rewardTimelock.setExternalAdmin(address(rewardDistributor), address(rewardTimelock));
        rewardTimelock.setDistributorRewards(address(rewardDistributor), tokensPerInterval);
        vm.stopPrank();
        assertEq(rewardDistributor.tokensPerInterval(), tokensPerInterval);
        assertEq(rewardDistributor.lastDistributionTime(), block.timestamp);
    }

    function testRewardTimelockSetPrivacy() public {
        vm.startPrank(OWNER);
        rewardTimelock.signalSetPrivacy(address(rewardTracker), true, true, true);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        rewardTimelock.setPrivacy(address(rewardTracker), true, true, true);
        vm.stopPrank();
        assertEq(rewardTracker.inPrivateTransferMode(), true);
        assertEq(rewardTracker.inPrivateStakingMode(), true);
        assertEq(rewardTracker.inPrivateClaimingMode(), true);
    }

    function testRewardTimelockWithdrawal() public {
        vm.startPrank(OWNER);
        WETH(weth).transfer(address(rewardTracker), 1e18);
        WETH(weth).transfer(address(rewardDistributor), 1e18);
        WETH(weth).transfer(address(rewardRouter), 1e18);
        rewardTimelock.signalWithdrawal(address(rewardTracker), weth, OWNER, 1e18);
        rewardTimelock.signalWithdrawal(address(rewardDistributor), weth, OWNER, 1e18);
        rewardTimelock.signalWithdrawal(address(rewardRouter), weth, OWNER, 1e18);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        rewardTimelock.withdrawTokens(address(rewardTracker), weth, OWNER, 1e18);
        rewardTimelock.withdrawTokens(address(rewardDistributor), weth, OWNER, 1e18);
        rewardTimelock.withdrawTokens(address(rewardRouter), weth, OWNER, 1e18);
        vm.stopPrank();
        assertEq(WETH(weth).balanceOf(address(rewardTracker)), 0);
        assertEq(WETH(weth).balanceOf(address(rewardDistributor)), 0);
        assertEq(WETH(weth).balanceOf(address(rewardRouter)), 0);
    }

    function testRewardTimelockCancelAction() public {
        vm.startPrank(OWNER);
        rewardTimelock.signalWithdrawal(address(rewardTracker), weth, OWNER, 1e18);
        vm.warp(block.timestamp + 2);
        vm.roll(block.number + 1);
        bytes32 action = keccak256(abi.encodePacked("withdrawal", address(rewardTracker), weth, OWNER, uint256(1e18)));
        rewardTimelock.cancelAction(action);
        vm.stopPrank();
        assertEq(rewardTimelock.pendingActions(action), 0);
    }
}
