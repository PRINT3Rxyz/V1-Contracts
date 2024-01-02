// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";
import {DeployP3} from "../../../script/DeployP3.s.sol";
import {Types} from "../../../script/Types.sol";
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

contract BrrrManagerTest is Test {
    address public OWNER;
    address public USER = makeAddr("user");

    HelperConfig public helperConfig;
    Types.Contracts contracts;
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
        DeployP3 deployScript = new DeployP3(); // Create a new instance of the DeployP3 script
        contracts = deployScript.run(); // Run the script and store the returned contracts

        wethUsdPriceFeed = contracts.networkConfig.wethUsdPriceFeed;
        wbtcUsdPriceFeed = contracts.networkConfig.wbtcUsdPriceFeed;
        usdcPriceFeed = contracts.networkConfig.usdcPriceFeed;
        deployerKey = contracts.networkConfig.deployerKey;
        OWNER = contracts.networkConfig.deployer;
        vm.deal(OWNER, 1e18 ether);

        vm.startPrank(OWNER);

        priceFeed = contracts.core.vaultPriceFeed;
        priceEvents = contracts.oracle.fastPriceEvents;
        fastPriceFeed = contracts.oracle.fastPriceFeed;
        vault = contracts.core.vault;
        usdp = contracts.tokens.usdp;
        router = contracts.core.router;
        vaultUtils = contracts.core.vaultUtils;
        shortsTracker = contracts.core.shortsTracker;
        orderBook = contracts.core.orderBook;
        positionManager = contracts.core.positionManager;
        positionRouter = contracts.core.positionRouter;
        brrr = contracts.core.brrr;
        brrrManager = contracts.core.brrrManager;
        vaultErrorController = contracts.core.vaultErrorController;
        referralStorage = contracts.referral.referralStorage;
        rewardRouter = contracts.staking.brrrRewardRouter;
        rewardTracker = contracts.staking.rewardTracker;
        rewardDistributor = contracts.staking.rewardDistributor;
        timelock = contracts.peripherals.timelock;
        transferStakedBrrr = contracts.staking.transferStakedBrrr;
        brrrBalance = contracts.staking.brrrBalance;
        orderBookReader = contracts.peripherals.orderBookReader;
        vaultReader = contracts.peripherals.vaultReader;
        rewardReader = contracts.peripherals.rewardReader;
        referralReader = contracts.referral.referralReader;
        reader = contracts.peripherals.reader;
        weth = contracts.tokens.weth;
        wbtc = contracts.tokens.wbtc;
        usdc = contracts.tokens.usdc;

        console.log("Deployed contracts");

        WBTC(wbtc).mint(OWNER, LARGE_AMOUNT);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        Token(usdc).mint(OWNER, LARGE_AMOUNT);

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

    modifier addLiquidity() {
        vm.startPrank(OWNER);
        WETH(weth).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(weth, DEPOSIT_AMOUNT, 0, 0);
        WBTC(wbtc).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(wbtc, DEPOSIT_AMOUNT, 0, 0);
        uint256 aumInUsdp = brrrManager.getAumInUsdp(true);
        uint256 brrrSupply = brrr.totalSupply();
        Token(usdc).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(usdc, DEPOSIT_AMOUNT, 0, 0);
        vm.stopPrank();
        _;
    }

    //////////////////
    // Setter Tests //
    //////////////////

    function testBrrrManagerLetsGovCallSetterFunctions() public {
        vm.startPrank(OWNER);
        brrrManager.setInPrivateMode(true);
        assertEq(brrrManager.inPrivateMode(), true);
        brrrManager.setShortsTracker(ShortsTracker(address(0)));
        assertEq(address(brrrManager.shortsTracker()), address(0));
        brrrManager.setShortsTrackerAveragePriceWeight(1);
        assertEq(brrrManager.shortsTrackerAveragePriceWeight(), 1);
        brrrManager.setHandler(USER, true);
        assertEq(brrrManager.isHandler(USER), true);
        brrrManager.setCooldownDuration(0);
        assertEq(brrrManager.cooldownDuration(), 0);
        brrrManager.setAumAdjustment(1, 1);
        assertEq(brrrManager.aumAddition(), 1);
        assertEq(brrrManager.aumDeduction(), 1);
        vm.stopPrank();
    }

    function testBrrrManagerSetterFunctionsDontWorkFromNonGov() public {
        vm.startPrank(USER);
        vm.expectRevert();
        brrrManager.setInPrivateMode(true);
        vm.expectRevert();
        brrrManager.setShortsTracker(ShortsTracker(address(0)));
        vm.expectRevert();
        brrrManager.setShortsTrackerAveragePriceWeight(1);
        vm.expectRevert();
        brrrManager.setHandler(USER, true);
        vm.expectRevert();
        brrrManager.setCooldownDuration(0);
        vm.expectRevert();
        brrrManager.setAumAdjustment(1, 1);
        vm.stopPrank();
    }
    //////////////////
    // Getter Tests //
    //////////////////

    function testBrrrManagerLetsUsGetThePriceOfBrrr() public addLiquidity returns (uint256) {
        uint256 price = brrrManager.getPrice(true);
        assertGt(price, 0);
        return price;
    }

    function testBrrrManagerLetsUsGetTheMaxAndMinAums() public view returns (uint256[] memory aums) {
        aums = brrrManager.getAums();
    }

    function testBrrrManagerLetsUsGetTheAumInUSDP() public addLiquidity returns (uint256) {
        uint256 aum = brrrManager.getAumInUsdp(true);
        assertGt(aum, 0);
        return aum;
    }

    function testBrrrManagerLetsUsGetTheMaxOrMinAum() public addLiquidity returns (uint256, uint256) {
        uint256 aumMax = brrrManager.getAum(true);
        uint256 aumMin = brrrManager.getAum(false);
        assertGt(aumMax, 0);
        assertGt(aumMin, 0);
        return (aumMax, aumMin);
    }

    function testBrrrReturnsTheIdWhenQueried() public {
        assertEq(brrr.id(), "BRRR-LP");
    }

    // `averagePrice` will default to 0 in getGlobalShortAveragePrice(_token)
    // Call will revert unless averagePrice > 0
    // A short must be opened on the vault for the call to return any value
    function testBrrrManagerLetsUsGetTheGlobalShortDeltaForAnyTokens() public {
        vm.expectRevert();
        brrrManager.getGlobalShortDelta(weth, 2000e8, 1e8);
    }

    function testBrrrManagerLetsUsGettheGlobalShortAveragePriceOfAToken() public view returns (uint256) {
        return brrrManager.getGlobalShortAveragePrice(weth);
    }

    ////////////////////
    // Function Tests //
    ////////////////////

    function testBrrrManagerLetsUsersAddLiquidityToReceiveBrrr() public giveUserCurrency {
        vm.startPrank(USER);
        WETH(weth).increaseAllowance(address(brrrManager), LARGE_AMOUNT);
        uint256 amount = brrrManager.addLiquidity(weth, 1e18, 0, 0);
        assertGt(amount, 0);
        uint256 brrrBal = brrr.balanceOf(USER);
        assertEq(amount, brrrBal);
        vm.stopPrank();
    }

    function testBrrrManagerLetsHandlersAddLiquidityOnBehalfOfAnotherAccountToReceiveBrrr() public giveUserCurrency {
        vm.startPrank(OWNER);
        brrrManager.setHandler(USER, true);
        WETH(weth).increaseAllowance(address(brrrManager), LARGE_AMOUNT);
        vm.stopPrank();
        vm.startPrank(USER);
        uint256 wethBalBefore = WETH(weth).balanceOf(USER);
        uint256 amount = brrrManager.addLiquidityForAccount(OWNER, USER, weth, 1e18, 0, 0);
        assertGt(amount, 0);
        uint256 wethBalAfter = WETH(weth).balanceOf(USER);
        uint256 brrrBal = brrr.balanceOf(USER);
        assertEq(brrrBal, amount);
        assertEq(wethBalBefore, wethBalAfter);
    }

    function testBrrrManagerLetsUsersRemoveLiquidityByBurningBrrr() public giveUserCurrency addLiquidity {
        vm.startPrank(USER);
        WETH(weth).increaseAllowance(address(brrrManager), LARGE_AMOUNT);
        uint256 amount = brrrManager.addLiquidity(weth, 1e18, 0, 0);
        assertGt(amount, 0);
        uint256 brrrBal = brrr.balanceOf(USER);
        assertEq(amount, brrrBal);
        vm.warp(block.timestamp + brrrManager.cooldownDuration() + 1);
        vm.roll(block.number + 1);
        brrr.approve(address(brrrManager), amount);
        uint256 wbtcBalBefore = WBTC(wbtc).balanceOf(USER);
        brrrManager.removeLiquidity(wbtc, amount, 1, USER);
        uint256 wbtcBalAfter = WBTC(wbtc).balanceOf(USER);
        assertGt(wbtcBalAfter, wbtcBalBefore);
        vm.stopPrank();
    }

    function testBrrrManagerLetsUsersWithdrawLiquidityInOtherCurrencies() public giveUserCurrency {
        vm.startPrank(USER);
        WETH(weth).increaseAllowance(address(brrrManager), LARGE_AMOUNT);
        uint256 amount = brrrManager.addLiquidity(weth, 1e18, 0, 0);
        assertGt(amount, 0);
        uint256 brrrBal = brrr.balanceOf(USER);
        assertEq(amount, brrrBal);
        vm.stopPrank();
    }

    function testBrrrManagerLetsHandlersRemoveLiquidityOnBehalfOfAnAccount() public giveUserCurrency {
        vm.startPrank(OWNER);
        brrrManager.setHandler(USER, true);
        WETH(weth).increaseAllowance(address(brrrManager), LARGE_AMOUNT);
        vm.stopPrank();
        vm.startPrank(USER);
        uint256 amount = brrrManager.addLiquidityForAccount(OWNER, OWNER, weth, 1e18, 0, 0);
        vm.warp(block.timestamp + brrrManager.cooldownDuration() + 1);
        vm.roll(block.number + 1);
        brrr.approve(address(brrrManager), amount);
        uint256 wethBalBefore = WETH(weth).balanceOf(OWNER);
        brrrManager.removeLiquidityForAccount(OWNER, weth, amount, 0, OWNER);
        vm.stopPrank();
        uint256 wethBalAfter = WETH(weth).balanceOf(OWNER);
        assertGt(wethBalAfter, wethBalBefore);
    }
}
