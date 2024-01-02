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
import {BrrrXpAmplifier} from "../../../src/staking/BrrrXpAmplifier.sol";
import {ShortsTrackerTimelock} from "../../../src/peripherals/ShortsTrackerTimelock.sol";
import {RewardClaimer} from "../../../src/staking/RewardClaimer.sol";
import {PriceFeedTimelock} from "../../../src/peripherals/PriceFeedTimelock.sol";
import {RewardTimelock} from "../../../src/peripherals/RewardTimelock.sol";

contract RewardTimelockTest is Test {
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
        amplifier = contracts.staking.brrrXpAmplifier;
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

        WETH(weth).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(weth, DEPOSIT_AMOUNT, 0, 0);
        WBTC(wbtc).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(wbtc, DEPOSIT_AMOUNT, 0, 0);
        Token(usdc).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(usdc, DEPOSIT_AMOUNT, 0, 0);

        rewardTimelock = new RewardTimelock(
            OWNER,
            1,
            OWNER,
            address(contracts.core.brrrManager),
            address(contracts.staking.brrrRewardRouter),
            address(contracts.staking.rewardDistributor)
        );
        rewardDistributor.setGov(address(rewardTimelock));
        rewardRouter.setGov(address(rewardTimelock));
        amplifier.setGov(address(rewardTimelock));

        // Required To Distribute Weekly Rewards
        rewardTimelock.setExternalAdmin(address(rewardDistributor), address(rewardTimelock));
        rewardTracker.setGov(address(rewardTimelock));
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
