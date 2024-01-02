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

contract OrderBookTest is Test {
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

        WETH(weth).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(weth, DEPOSIT_AMOUNT, 0, 0);
        WBTC(wbtc).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(wbtc, DEPOSIT_AMOUNT, 0, 0);
        Token(usdc).increaseAllowance(address(brrrManager), type(uint256).max);
        brrrManager.addLiquidity(usdc, DEPOSIT_AMOUNT, 0, 0);

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
    // Setter Tests //
    //////////////////
    function testOrderBookCantBeInitializedTwice() public {
        vm.startPrank(OWNER);
        vm.expectRevert();
        orderBook.initialize(
            address(router), address(vault), weth, address(usdp), 300000000000000, 10000000000000000000000000000000
        );
        vm.stopPrank();
    }

    function testSetterFunctionsWorkFromGovOnOrderBook() public {
        vm.startPrank(OWNER);
        orderBook.setMinExecutionFee(0);
        uint256 fee = orderBook.minExecutionFee();
        assertEq(fee, 0);
        orderBook.setMinPurchaseTokenAmountUsd(0);
        uint256 amount = orderBook.minPurchaseTokenAmountUsd();
        assertEq(amount, 0);
        orderBook.setGov(USER);
        address gov = orderBook.gov();
        assertEq(gov, USER);
        vm.stopPrank();
    }

    function testOnlyGovHasAccessToSetterFunctionsOnOrderBook() public {
        vm.startPrank(USER);
        vm.expectRevert();
        orderBook.setMinExecutionFee(0);
        vm.expectRevert();
        orderBook.setMinPurchaseTokenAmountUsd(0);
        vm.expectRevert();
        orderBook.setGov(USER);
        vm.stopPrank();
    }

    ////////////////////
    // Function Tests //
    ////////////////////

    // Creating Orders
    function testOrderBookLetsUsOpenLongLimitOrdersFromAnyUser()
        public
        giveUserCurrency
        returns (uint256[] memory uintProps, address[] memory addressProps)
    {
        vm.startPrank(USER);
        wethArray.push(address(weth));
        address[] memory _path = wethArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path,
            1e18,
            weth,
            0,
            35689554309499200000000000000000000,
            weth,
            true,
            2061587547909500000000000000000000,
            true,
            300000000000000,
            false
        );
        // Check the limit order is there
        numberArray.push(0);
        uint256[] memory _indices = numberArray;
        (uintProps, addressProps) = orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        vm.stopPrank();
    }

    function testOrderBookLetsUsOpenShortLimitOrdersFromAnyUser()
        public
        giveUserCurrency
        returns (uint256[] memory uintProps, address[] memory addressProps)
    {
        vm.startPrank(USER);
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path,
            1e18,
            weth,
            0,
            35689554309499200000000000000000000,
            weth,
            false,
            2061587547909500000000000000000000,
            true,
            300000000000000,
            false
        );
        // Check the limit order is there
        numberArray.push(0);
        uint256[] memory _indices = numberArray;
        (uintProps, addressProps) = orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        vm.stopPrank();
    }

    function testOrderBookLetsUsOpenSwapOrdersFromAnyUser()
        public
        giveUserCurrency
        returns (
            address path0,
            address path1,
            address path2,
            uint256 amountIn,
            uint256 minOut,
            uint256 triggerRatio,
            bool triggerAboveThreshold,
            bool shouldUnwrap,
            uint256 executionFee
        )
    {
        vm.startPrank(USER);
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createSwapOrder{value: 300000000000000}(_path, 1e18, 0, 1000, true, 300000000000000, false, false);
        // Check the swap order is there
        return orderBook.getSwapOrder(USER, 0);
    }

    // Cancelling Orders
    function testOrderBookLetsUsCancelOurOwnOrders() public giveUserCurrency {
        vm.startPrank(USER);
        wethArray.push(address(weth));
        address[] memory _path = wethArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path,
            1e18,
            weth,
            0,
            35689554309499200000000000000000000,
            weth,
            true,
            2061587547909500000000000000000000,
            true,
            300000000000000,
            false
        );
        // Check the limit order is there
        numberArray.push(0);
        uint256[] memory _indices = numberArray;
        (uint256[] memory uintPropsBefore, address[] memory addressPropsBefore) =
            orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        // Cancel the order
        orderBook.cancelIncreaseOrder(0);
        // Check the order is gone
        (uint256[] memory uintPropsAfter, address[] memory addressPropsAfter) =
            orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        bytes32 hashBefore = keccak256(abi.encodePacked(uintPropsBefore, addressPropsBefore));
        bytes32 hashAfter = keccak256(abi.encodePacked(uintPropsAfter, addressPropsAfter));
        assertNotEq(hashBefore, hashAfter);
        vm.stopPrank();
    }

    function testOrderBookDoesntLetOthersCancelYourOrder() public giveUserCurrency {
        vm.startPrank(USER);
        wethArray.push(address(weth));
        address[] memory _path = wethArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path,
            1e18,
            weth,
            0,
            35689554309499200000000000000000000,
            weth,
            true,
            2061587547909500000000000000000000,
            true,
            300000000000000,
            false
        );
        // Check the limit order is there
        numberArray.push(0);
        uint256[] memory _indices = numberArray;
        orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        vm.stopPrank();

        vm.prank(OWNER);
        vm.expectRevert();
        orderBook.cancelIncreaseOrder(0);
    }

    function testOrderBookLetsUsersCancelSwapOrders() public giveUserCurrency {
        vm.startPrank(USER);
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createSwapOrder{value: 300000000000000}(_path, 1e18, 0, 1000, true, 300000000000000, false, false);
        // Check the swap order is there
        orderBook.getSwapOrder(USER, 0);
        // Cancel the order
        orderBook.cancelSwapOrder(0);
        // Check the order is gone
        vm.stopPrank();
        (
            address path0,
            address path1,
            address path2,
            uint256 amountIn,
            uint256 minOut,
            uint256 triggerRatio,
            bool triggerAboveThreshold,
            bool shouldUnwrap,
            uint256 executionFee
        ) = orderBook.getSwapOrder(USER, 0);
        assertEq(path0, address(0));
        assertEq(path1, address(0));
        assertEq(path2, address(0));
        assertEq(amountIn, 0);
        assertEq(minOut, 0);
        assertEq(triggerRatio, 0);
        assertEq(triggerAboveThreshold, false);
        assertEq(shouldUnwrap, false);
        assertEq(executionFee, 0);
    }

    // Updating Orders
    function testOrderBookLetsUsersUpdateExistingLimitOrders() public giveUserCurrency {
        vm.startPrank(USER);
        wethArray.push(address(weth));
        address[] memory _path = wethArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path,
            1e18,
            weth,
            0,
            35689554309499200000000000000000000,
            weth,
            true,
            2061587547909500000000000000000000,
            true,
            300000000000000,
            false
        );
        // Check the limit order is there
        numberArray.push(0);
        uint256[] memory _indices = numberArray;
        (uint256[] memory uintPropsBefore, address[] memory addressPropsBefore) =
            orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        // Update the order
        orderBook.updateIncreaseOrder(0, 35689554309499200000000000000000000, 1861587547909500000000000000000000, true);
        // Check the order is gone
        (uint256[] memory uintPropsAfter, address[] memory addressPropsAfter) =
            orderBookReader.getIncreaseOrders(payable(address(orderBook)), USER, _indices);
        bytes32 hashBefore = keccak256(abi.encodePacked(uintPropsBefore, addressPropsBefore));
        bytes32 hashAfter = keccak256(abi.encodePacked(uintPropsAfter, addressPropsAfter));
        assertNotEq(hashBefore, hashAfter);
        vm.stopPrank();
    }

    function testOrderBookLetsUsersUpdateExistingSwapOrders() public giveUserCurrency {
        vm.startPrank(USER);
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        orderBook.createSwapOrder{value: 300000000000000}(_path, 1e18, 0, 1000, true, 300000000000000, false, false);
        // Update the order: Min Out to 1000
        orderBook.updateSwapOrder(0, 1000, 1000, true);
        (,,,, uint256 minOut,,,,) = orderBook.getSwapOrder(USER, 0);
        assertEq(minOut, 1000);
        vm.stopPrank();
    }
    // Executing Orders => Positions Can Only Execute If Price Hits Limit

    function testOrderBookLimitShortPositions() public giveUserCurrency {
        vm.startPrank(USER);
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).approve(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path, 1e18, weth, 0, 9e34, usdc, false, 1661587547909500000000000000000000, true, 300000000000000, false
        );
        vm.stopPrank();
        uint256 _orderIndex = orderBook.increaseOrdersIndex(USER) - 1;
        vm.prank(OWNER);
        positionManager.executeIncreaseOrder(USER, _orderIndex, payable(msg.sender));
    }

    function testOrderBookLimitLongPositions() public giveUserCurrency {
        vm.startPrank(USER);
        wethArray.push(address(weth));
        address[] memory _path = wethArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).approve(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path, 1e18, weth, 0, 9e34, weth, true, 1661587547909500000000000000000000, true, 300000000000000, false
        );
        vm.stopPrank();
        uint256 _orderIndex = orderBook.increaseOrdersIndex(USER) - 1;
        vm.prank(OWNER);
        positionManager.executeIncreaseOrder(USER, _orderIndex, payable(msg.sender));
    }

    function testOrderBookLimitPositionsWithDelay() public giveUserCurrency {
        vm.startPrank(USER);
        wethArray.push(address(weth));
        address[] memory _path = wethArray;
        router.approvePlugin(address(orderBook));
        WETH(weth).approve(address(router), LARGE_AMOUNT);
        orderBook.createIncreaseOrder{value: 300000000000000}(
            _path, 1e18, weth, 0, 1e34, weth, true, 1661587547909500000000000000000000, true, 300000000000000, false
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days);
        vm.roll(block.number + 1);
        uint256 _orderIndex = orderBook.increaseOrdersIndex(USER) - 1;
        vm.prank(OWNER);
        positionManager.executeIncreaseOrder(USER, _orderIndex, payable(msg.sender));
    }
}
