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

contract PositionRouterTest is Test {
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

        // Set USER to keeper
        positionRouter.setPositionKeeper(USER, true);

        wbtcArray.push(wbtc);
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
    // Setter tests //
    //////////////////

    function testAnAdminCanCallSetterFunctions() public {
        vm.startPrank(OWNER);
        positionRouter.setPositionKeeper(OWNER, true);
        positionRouter.setCallbackGasLimit(800000);
        positionRouter.setCustomCallbackGasLimit(address(positionRouter), 800000);
        positionRouter.setMinExecutionFee(300000000000000);
        positionRouter.setIsLeverageEnabled(true);
        positionRouter.setDelayValues(0, 180, 1800);
        positionRouter.setRequestKeysStartValues(0, 0);
        vm.stopPrank();
    }

    function testANonAdminIsUnableToCallSetterFunctions() public {
        vm.startPrank(USER);
        vm.expectRevert();
        positionRouter.setPositionKeeper(USER, true);
        vm.expectRevert();
        positionRouter.setCallbackGasLimit(800000);
        vm.expectRevert();
        positionRouter.setCustomCallbackGasLimit(address(positionRouter), 800000);
        vm.expectRevert();
        positionRouter.setMinExecutionFee(300000000000000);
        vm.expectRevert();
        positionRouter.setIsLeverageEnabled(true);
        vm.expectRevert();
        positionRouter.setDelayValues(0, 180, 1800);
        vm.expectRevert();
        positionRouter.setRequestKeysStartValues(0, 0);
        vm.stopPrank();
    }

    ////////////////////
    // Function Tests //
    ////////////////////

    // createIncreasePositionETH
    function testCreateIncreasePositionEthLetsUserOpenLongPositions()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionRouter));
        bytes32 _key = positionRouter.createIncreasePositionETH{value: 10 ether}(
            _path,
            wbtc,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        positionRouter.executeIncreasePosition(_key, payable(OWNER));
        boolArray.push(true);
        bool[] memory _boolArray = boolArray;
        returnArray = reader.getPositions(address(vault), USER, wbtcArray, wbtcArray, _boolArray);
    }

    function testCreateIncreasePositionEthFailsIfInsufficientFeeProvided() public giveUserCurrency {
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionRouter));
        vm.expectRevert();
        positionRouter.createIncreasePositionETH{value: 10 ether}(
            _path,
            wbtc,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            1,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
    }

    function testCreateIncreasePositionEthFailsIfIncorrectPathProvided() public giveUserCurrency {
        vm.startPrank(USER);
        wbtcToUsdcArray.push(wbtc);
        wbtcToUsdcArray.push(usdc);
        address[] memory _path = wbtcToUsdcArray;
        router.approvePlugin(address(positionRouter));
        vm.expectRevert();
        positionRouter.createIncreasePositionETH{value: 10 ether}(
            _path,
            wbtc,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
    }

    function testCreateIncreasePositionEthLetsUserOpenShortPositions()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.startPrank(USER);
        wethToUsdcArray.push(weth);
        wethToUsdcArray.push(usdc);
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(positionRouter));
        bytes32 _key = positionRouter.createIncreasePositionETH{value: 10 ether}(
            _path,
            wbtc,
            0,
            35689554309499200000000000000000000,
            false,
            100000000000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        positionRouter.executeIncreasePosition(_key, payable(OWNER));
        boolArray.push(false);
        usdcArray.push(usdc);
        address[] memory _usdcArray = usdcArray;
        bool[] memory _boolArray = boolArray;
        returnArray = reader.getPositions(address(vault), USER, _usdcArray, wbtcArray, _boolArray);
    }

    function tesCreateIncreasePositionEthRequiresStablecoinsForShortCollateral() public giveUserCurrency {
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionRouter));
        vm.expectRevert();
        positionRouter.createIncreasePositionETH{value: 10 ether}(
            _path,
            wbtc,
            0,
            35689554309499200000000000000000000,
            false,
            100000000000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
    }
    // Create increase position

    function testCreateIncreasePositionLetsUserOpenLongPositions()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.startPrank(USER);
        // Open a long position
        router.approvePlugin(address(positionRouter));
        WBTC(wbtc).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            wbtcArray,
            address(wbtc),
            1e8,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        positionRouter.executeIncreasePosition(_key, payable(OWNER));
        // Check the position was successfully opened
        boolArray.push(true);
        bool[] memory _boolArray = boolArray;
        returnArray = reader.getPositions(address(vault), USER, wbtcArray, wbtcArray, _boolArray);
    }

    function testCreateIncreasePositionLetsUserOpenShortPositions()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.startPrank(USER);
        // Open a short position
        wethToUsdcArray.push(weth);
        wethToUsdcArray.push(usdc);
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(positionRouter));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            address(wbtc),
            1e18,
            0,
            35689554309499200000000000000000000,
            false,
            100000000000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        positionRouter.executeIncreasePosition(_key, payable(OWNER));
        // Check the position was successfully opened
        boolArray.push(false);
        usdcArray.push(usdc);
        address[] memory _collateral = usdcArray;
        bool[] memory _boolArray = boolArray;
        returnArray = reader.getPositions(address(vault), USER, _collateral, wbtcArray, _boolArray);
    }

    function testCreateIncreasePositionOnlyAllowsShortsWithStableCollateral() public giveUserCurrency {
        vm.startPrank(USER);
        // Open a short position
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionRouter));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            address(wbtc),
            1e18,
            0,
            35689554309499200000000000000000000,
            false,
            100000000000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);
        vm.startPrank(OWNER);
        vm.expectRevert();
        positionRouter.executeIncreasePosition(_key, payable(OWNER));
        vm.stopPrank();
    }

    // Create decrease position

    function testPositionRouterLetsUsCloseALongPositionAfterItsOpened() public giveUserCurrency {
        vm.startPrank(USER);
        // Open a long position
        router.approvePlugin(address(positionRouter));
        WBTC(wbtc).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            wbtcArray,
            address(wbtc),
            1e8,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);
        vm.startPrank(OWNER);
        bool increaseSuccess = positionRouter.executeIncreasePosition(_key, payable(OWNER));
        // Set max leverage so call doesn't fail
        timelock.setMaxLeverage(address(vault), 10000000);
        vm.stopPrank();
        assertTrue(increaseSuccess);
        // Close the long position
        vm.startPrank(USER);
        bytes32 _key2 = positionRouter.createDecreasePosition{value: 300000000000000}(
            wbtcArray,
            address(wbtc),
            362607074682315577285163543610613,
            736622047984936200000000000000000,
            true,
            USER,
            312768478400000000000000000000000,
            0,
            300000000000000,
            false,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.prank(OWNER);
        bool decreaseSuccess = positionRouter.executeDecreasePosition(_key2, payable(OWNER));
        assertTrue(decreaseSuccess);
    }

    // Close Short => Path passed into decrease must be opposite of the path to increase
    function testPositionRouterLetsUsCloseAShortPositionAfterItsOpened() public giveUserCurrency {
        vm.startPrank(USER);
        // Open a short position
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(positionRouter));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            address(weth),
            1e19,
            0,
            35689554309499200000000000000000000,
            false,
            1661587547909500000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.prank(OWNER);
        bool increaseSuccess = positionRouter.executeIncreasePosition(_key, payable(OWNER));
        assertTrue(increaseSuccess);
        // Check the position was successfully opened
        vm.startPrank(USER);
        usdcArray.push(address(usdc));
        address[] memory _usdcArray = usdcArray;
        boolArray.push(false);
        bool[] memory _boolArray = boolArray;
        wethArray.push(address(weth));
        address[] memory _wethArray = wethArray;
        reader.getPositions(address(vault), OWNER, _usdcArray, _wethArray, _boolArray);
        // Close the short position
        usdcToWethArray.push(address(usdc));
        usdcToWethArray.push(address(weth));
        address[] memory _path2 = usdcToWethArray;
        bytes32 _key2 = positionRouter.createDecreasePosition{value: 300000000000000}(
            _path2,
            address(weth),
            362607074682315577285163543610613,
            35689554309499200000000000000000000,
            false,
            OWNER,
            2061587547909500000000000000000000,
            0,
            300000000000000,
            false,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.prank(OWNER);
        bool decreaseSuccess = positionRouter.executeDecreasePosition(_key2, payable(OWNER));
        assertTrue(decreaseSuccess);
    }

    // Cancel increase position
    function testCancelIncreasePosition() public giveUserCurrency {
        vm.startPrank(USER);
        wethArray.push(weth);
        address[] memory _path = wethArray;
        router.approvePlugin(address(positionRouter));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            weth,
            1e8,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        bool success = positionRouter.cancelIncreasePosition(_key, payable(USER));
        assertTrue(success);
        vm.stopPrank();
    }

    // Test referral code
    function testDiscountIsAppliedWhenAReferralCodeIsUsed() public giveUserCurrency {
        bytes32 code = keccak256(abi.encodePacked("Random Value"));
        vm.startPrank(OWNER);
        referralStorage.registerCode(code);
        vm.stopPrank();

        vm.startPrank(USER);
        wethArray.push(weth);
        address[] memory _path = wethArray;
        router.approvePlugin(address(positionRouter));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            weth,
            1e18,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            code,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);

        vm.startPrank(OWNER);
        positionRouter.executeIncreasePosition(_key, payable(OWNER));
        vm.stopPrank();
    }
    // Execute increase position (s) => should work for non keeper after delay

    function testExecuteIncreasePositionWorksForNonKeepersAfterDelay() public giveUserCurrency {
        vm.startPrank(USER);
        // Open a long position
        address[] memory _path = wbtcArray;
        router.approvePlugin(address(positionRouter));
        WBTC(wbtc).increaseAllowance(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            address(wbtc),
            1e8,
            0,
            35689554309499200000000000000000000,
            true,
            31276847840000000000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        vm.startPrank(OWNER);
        bool increaseSuccess = positionRouter.executeIncreasePosition(_key, payable(OWNER));
        // Set max leverage so call doesn't fail
        timelock.setMaxLeverage(address(vault), 10000000);
        vm.stopPrank();
        assertTrue(increaseSuccess);
        // Close the long position
        vm.startPrank(USER);
        bytes32 _key2 = positionRouter.createDecreasePosition{value: 300000000000000}(
            _path,
            address(wbtc),
            362607074682315577285163543610613,
            736622047984936200000000000000000,
            true,
            USER,
            312768478400000000000000000000000,
            0,
            300000000000000,
            false,
            0x0000000000000000000000000000000000000000
        );
        vm.warp(block.timestamp + 181);
        vm.roll(block.number + 1);
        bool decreaseSuccess = positionRouter.executeDecreasePosition(_key2, payable(USER));
        assertTrue(decreaseSuccess);
        vm.stopPrank();
    }

    function testShortingWorksOnHigherLeverages() public giveUserCurrency {
        vm.startPrank(USER);
        // Open a short position
        wethToUsdcArray.push(address(weth));
        wethToUsdcArray.push(address(usdc));
        address[] memory _path = wethToUsdcArray;
        router.approvePlugin(address(positionRouter));
        WETH(weth).approve(address(router), LARGE_AMOUNT);
        bytes32 _key = positionRouter.createIncreasePosition{value: 300000000000000}(
            _path,
            address(weth),
            1e18,
            0,
            9e34,
            false,
            1661587547909500000000000000000000,
            300000000000000,
            0x0000000000000000000000000000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );
        vm.stopPrank();
        vm.prank(OWNER);
        bool increaseSuccess = positionRouter.executeIncreasePosition(_key, payable(OWNER));
        assertTrue(increaseSuccess);
    }
}
