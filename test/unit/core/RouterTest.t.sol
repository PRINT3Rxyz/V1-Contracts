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

contract RouterTest is Test {
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
    address[] wbtcToWethArray; // WBTC => WETH
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

        tokenArray.push(weth);
        tokenArray.push(wbtc);

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

    function testRouterSetterFunctionsCanBeCalledByGov() public {
        vm.startPrank(OWNER);
        router.addPlugin(address(positionRouter));
        assertEq(router.plugins(address(positionRouter)), true);
        router.removePlugin(address(positionRouter));
        assertEq(router.plugins(address(positionRouter)), false);
        vm.stopPrank();
    }

    function testUsersCanApproveAndDenyPluginsAtWill() public {
        vm.startPrank(USER);
        router.approvePlugin(address(positionRouter));
        assertEq(router.approvedPlugins(USER, address(positionRouter)), true);
        router.denyPlugin(address(positionRouter));
        assertEq(router.approvedPlugins(USER, address(positionRouter)), false);
        vm.stopPrank();
    }

    function testRouterSetterFunctionsCantBeCalledByNonGov() public {
        vm.startPrank(USER);
        vm.expectRevert();
        router.addPlugin(address(positionRouter));
        vm.expectRevert();
        router.removePlugin(address(positionRouter));
        vm.stopPrank();
    }
    //////////////////
    // Getter Tests //
    //////////////////

    ////////////////////
    // Function Tests //
    ////////////////////

    /* 
    Plugin Transfer, Plugin Increase Position, Plugin Decrease Position can only be called by an external plugin. 
    These functions are validated in the PositonRouter/PositionManager/OrderBook tests
    */

    function testRouterDirectPoolDeposit() public giveUserCurrency {
        vm.startPrank(USER);
        uint256 balBefore = WETH(weth).balanceOf(USER);
        WETH(weth).increaseAllowance(address(router), DEPOSIT_AMOUNT);
        router.directPoolDeposit(weth, DEPOSIT_AMOUNT);
        uint256 balAfter = WETH(weth).balanceOf(USER);
        assertEq(balBefore - balAfter, DEPOSIT_AMOUNT);
        vm.stopPrank();
    }

    // Doesn't test calculations are accurate.
    function testRouterSwap() public giveUserCurrency {
        vm.startPrank(USER);
        wethToUsdcArray.push(weth);
        wethToUsdcArray.push(usdc);
        uint256 wethBalBefore = WETH(weth).balanceOf(USER);
        uint256 usdcBalBefore = Token(usdc).balanceOf(USER);
        WETH(weth).increaseAllowance(address(router), DEPOSIT_AMOUNT);
        router.swap(wethToUsdcArray, 1e18, 0, USER);
        uint256 wethBalAfter = WETH(weth).balanceOf(USER);
        uint256 usdcBalAfter = Token(usdc).balanceOf(USER);
        assertLt(wethBalAfter, wethBalBefore);
        assertGt(usdcBalAfter, usdcBalBefore);
        vm.stopPrank();
    }

    // Doesn't test calculations are accurate.
    function testRouterSwapEthToTokens() public giveUserCurrency {
        vm.startPrank(USER);
        wethToUsdcArray.push(weth);
        wethToUsdcArray.push(usdc);
        uint256 usdcBalBefore = Token(usdc).balanceOf(USER);
        router.swapETHToTokens{value: 1e18}(wethToUsdcArray, 0, USER);
        uint256 usdcBalAfter = Token(usdc).balanceOf(USER);
        assertGt(usdcBalAfter, usdcBalBefore);
        vm.stopPrank();
    }

    // Doesn't test calculations are accurate.
    function testRouterSwapsTokensToEth() public giveUserCurrency {
        vm.startPrank(USER);
        usdcToWethArray.push(usdc);
        usdcToWethArray.push(weth);
        uint256 startingEthBalance = address(USER).balance;
        Token(usdc).increaseAllowance(address(router), DEPOSIT_AMOUNT);
        router.swapTokensToETH(usdcToWethArray, 1e10, 0, payable(USER));
        uint256 endingEthBalance = address(USER).balance;
        assertGt(endingEthBalance, startingEthBalance);
        vm.stopPrank();
    }

    // Leverage must be enabled to call from Router
    function testRouterIncreasePosition() public giveUserCurrency {
        vm.prank(OWNER);
        timelock.enableLeverage(address(vault));
        vm.startPrank(USER);
        wethArray.push(weth);
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        router.increasePosition(
            wethArray, weth, 1e19, 0, 35689554309499200000000000000000000, true, 2661587547909500000000000000000000
        );
        vm.stopPrank();
        boolArray.push(true);
        uint256[] memory returnArray = reader.getPositions(address(vault), USER, wethArray, wethArray, boolArray);
        assertNotEq(returnArray[0], 0);
    }

    // Leverage must be enabled to call from Router
    function testRouterIncreasePositionEth() public giveUserCurrency {
        vm.prank(OWNER);
        timelock.enableLeverage(address(vault));
        vm.startPrank(USER);
        wethArray.push(weth);
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        router.increasePositionETH{value: 1e19}(
            wethArray, weth, 0, 35689554309499200000000000000000000, true, 2661587547909500000000000000000000
        );
        vm.stopPrank();
        boolArray.push(true);
        uint256[] memory returnArray = reader.getPositions(address(vault), USER, wethArray, wethArray, boolArray);
        assertNotEq(returnArray[0], 0);
    }

    function testRouterDecreasePosition() public giveUserCurrency {
        vm.startPrank(OWNER);
        timelock.enableLeverage(address(vault));
        timelock.setMaxLeverage(address(vault), 10000000);
        vm.stopPrank();

        vm.startPrank(USER);
        // Open a long position
        wbtcArray.push(address(wbtc));
        WBTC(wbtc).increaseAllowance(address(router), LARGE_AMOUNT);
        router.increasePosition(
            wbtcArray, wbtc, 1e8, 0, 35689554309499200000000000000000000, true, 31276847840000000000000000000000000
        );
        boolArray.push(true);
        uint256[] memory startPosition = reader.getPositions(address(vault), USER, wbtcArray, wbtcArray, boolArray);
        assertGt(startPosition[0], 0);
        // Close the long position
        router.decreasePosition(
            wbtc,
            wbtc,
            362607074682315577285163543610613,
            736622047984936200000000000000000,
            true,
            USER,
            312768478400000000000000000000000
        );
        uint256[] memory endPosition = reader.getPositions(address(vault), USER, wbtcArray, wbtcArray, boolArray);
        bytes32 startHash = keccak256(abi.encodePacked(startPosition));
        bytes32 endHash = keccak256(abi.encodePacked(endPosition));
        assertNotEq(startHash, endHash);
        vm.stopPrank();
    }

    function testRouterDecreasePositionETH() public giveUserCurrency {
        vm.startPrank(OWNER);
        timelock.enableLeverage(address(vault));
        timelock.setMaxLeverage(address(vault), 10000000);
        vm.stopPrank();

        vm.startPrank(USER);
        // Open a long position
        wethArray.push(address(weth));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        router.increasePosition(
            wethArray, weth, 1e18, 0, 35689554309499200000000000000000000, true, 31276847840000000000000000000000000
        );
        boolArray.push(true);
        uint256[] memory position = reader.getPositions(address(vault), USER, wethArray, wethArray, boolArray);
        assertGt(position[0], 0);
        uint256 balBefore = address(USER).balance;
        router.decreasePositionETH(
            weth,
            weth,
            362607074682315577285163543610613,
            736622047984936200000000000000000,
            true,
            payable(USER),
            312768478400000000000000000000000
        );
        uint256 balAfter = address(USER).balance;
        assertGt(balAfter, balBefore);
        vm.stopPrank();
    }

    function testRouterDecreasePositionAndSwap() public giveUserCurrency {
        vm.startPrank(OWNER);
        timelock.enableLeverage(address(vault));
        timelock.setMaxLeverage(address(vault), 10000000);
        vm.stopPrank();

        vm.startPrank(USER);
        // Open a long position
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        router.increasePosition(
            tokenArray, wbtc, 1e18, 0, 35689554309499200000000000000000000, true, 31276847840000000000000000000000000
        );
        boolArray.push(true);
        wbtcArray.push(wbtc);
        uint256[] memory startPosition = reader.getPositions(address(vault), USER, wbtcArray, wbtcArray, boolArray);
        assertGt(startPosition[0], 0);
        // Close the long position
        wbtcToUsdcArray.push(wbtc);
        wbtcToUsdcArray.push(usdc);
        uint256 usdcBalBefore = Token(usdc).balanceOf(USER);
        router.decreasePositionAndSwap(
            wbtcToUsdcArray,
            wbtc,
            362607074682315577285163543610613,
            736622047984936200000000000000000,
            true,
            USER,
            312768478400000000000000000000000,
            1
        );
        uint256 usdcBalAfter = Token(usdc).balanceOf(USER);
        assertGt(usdcBalAfter, usdcBalBefore);
        vm.stopPrank();
    }

    function testRouterDecreasePositionAndSwapEth() public giveUserCurrency {
        vm.startPrank(OWNER);
        timelock.enableLeverage(address(vault));
        timelock.setMaxLeverage(address(vault), 10000000);
        vm.stopPrank();

        vm.startPrank(USER);
        // Open a long position
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        router.increasePosition(
            tokenArray, wbtc, 1e18, 0, 35689554309499200000000000000000000, true, 31276847840000000000000000000000000
        );
        boolArray.push(true);
        wbtcArray.push(wbtc);
        uint256[] memory startPosition = reader.getPositions(address(vault), USER, wbtcArray, wbtcArray, boolArray);
        assertGt(startPosition[0], 0);
        // Close the long position
        wbtcToWethArray.push(wbtc);
        wbtcToWethArray.push(weth);
        uint256 balBefore = address(USER).balance;
        router.decreasePositionAndSwapETH(
            wbtcToWethArray,
            wbtc,
            362607074682315577285163543610613,
            736622047984936200000000000000000,
            true,
            payable(USER),
            312768478400000000000000000000000,
            1
        );
        uint256 balAfter = address(USER).balance;
        assertGt(balAfter, balBefore);
        vm.stopPrank();
    }
}
