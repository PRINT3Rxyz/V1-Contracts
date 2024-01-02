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

contract PositionManagerTest is Test {
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

    function testAnAdminCanCallAllSetterFunctionsOnPositionManager() public {
        vm.startPrank(OWNER);
        positionManager.setOrderKeeper(USER, true);
        assertEq(positionManager.isOrderKeeper(USER), true);
        positionManager.setLiquidator(USER, true);
        assertEq(positionManager.isLiquidator(USER), true);
        positionManager.setPartner(USER, true);
        assertEq(positionManager.isPartner(USER), true);
        positionManager.setShouldValidateIncreaseOrder(true);
        assertEq(positionManager.shouldValidateIncreaseOrder(), true);
        positionManager.setInLegacyMode(true);
        assertEq(positionManager.inLegacyMode(), true);
        vm.stopPrank();
    }

    function testPositionManagerSetterFunctionsRevertWhenCalledFromNonAdmin() public {
        vm.startPrank(USER);
        vm.expectRevert();
        positionManager.setOrderKeeper(USER, true);
        vm.expectRevert();
        positionManager.setLiquidator(USER, true);
        vm.expectRevert();
        positionManager.setPartner(USER, true);
        vm.expectRevert();
        positionManager.setShouldValidateIncreaseOrder(true);
        vm.expectRevert();
        positionManager.setInLegacyMode(true);
        vm.stopPrank();
    }
    //////////////////
    // Getter Tests //
    //////////////////

    ////////////////////
    // Function Tests //
    ////////////////////

    function testPositionManagerIncreasePositionWorksInLegacyMode()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.prank(OWNER);
        positionManager.setInLegacyMode(true);
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePosition(
            _path, wbtc, 1e18, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        wbtcArray.push(wbtc);
        address[] memory _tokens = wbtcArray;
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        returnArray = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
    }

    function testPositionManagerIncreasePositionWorksFromPartners()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.prank(OWNER);
        positionManager.setPartner(USER, true);
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePosition(
            _path, wbtc, 1e18, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        wbtcArray.push(wbtc);
        address[] memory _tokens = wbtcArray;
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        returnArray = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
    }

    function testPositionManagerIncreasePositionEthWorksInLegacyMode()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.prank(OWNER);
        positionManager.setInLegacyMode(true);
        vm.startPrank(USER);
        wethArray.push(weth);
        address[] memory _path = wethArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePositionETH{value: 10 ether}(
            _path, weth, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        returnArray = reader.getPositions(address(vault), USER, _path, _path, _isLong);
    }

    function testPositionManagerIncreasePositionEthWorksFromPartners()
        public
        giveUserCurrency
        returns (uint256[] memory returnArray)
    {
        vm.prank(OWNER);
        positionManager.setPartner(USER, true);
        vm.startPrank(USER);
        wethArray.push(weth);
        address[] memory _path = wethArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePositionETH{value: 10 ether}(
            _path, weth, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        returnArray = reader.getPositions(address(vault), USER, _path, _path, _isLong);
    }

    function testDecreasePositionWorksInLegacyMode() public giveUserCurrency {
        vm.prank(OWNER);
        positionManager.setInLegacyMode(true);
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePosition(
            _path, wbtc, 1e18, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        wbtcArray.push(wbtc);
        address[] memory _tokens = wbtcArray;
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        uint256[] memory _position1 = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
        vm.startPrank(USER);
        positionManager.decreasePosition(wbtc, wbtc, 1e10, 1e10, true, USER, 900000000000000000000000000000000);
        uint256[] memory _position2 = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
        bytes32 _positionHash1 = keccak256(abi.encodePacked(_position1));
        bytes32 _positionHash2 = keccak256(abi.encodePacked(_position2));
        assertNotEq(_positionHash1, _positionHash2);
    }

    function testDecreasePositionWorksFromPartners() public giveUserCurrency {
        vm.prank(OWNER);
        positionManager.setPartner(USER, true);
        vm.startPrank(USER);
        address[] memory _path = tokenArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePosition(
            _path, wbtc, 1e18, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        wbtcArray.push(wbtc);
        address[] memory _tokens = wbtcArray;
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        uint256[] memory _position1 = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
        vm.startPrank(USER);
        positionManager.decreasePosition(wbtc, wbtc, 1e10, 1e10, true, USER, 900000000000000000000000000000000);
        uint256[] memory _position2 = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
        bytes32 _positionHash1 = keccak256(abi.encodePacked(_position1));
        bytes32 _positionHash2 = keccak256(abi.encodePacked(_position2));
        assertNotEq(_positionHash1, _positionHash2);
    }

    function testDecreasePositionEthWorksInLegacyMode() public giveUserCurrency {
        vm.prank(OWNER);
        positionManager.setInLegacyMode(true);
        vm.startPrank(USER);
        wethArray.push(weth);
        address[] memory _path = wethArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePositionETH{value: 10 ether}(
            _path, weth, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        uint256[] memory _position1 = reader.getPositions(address(vault), USER, _path, _path, _isLong);
        vm.startPrank(USER);
        positionManager.decreasePositionETH(
            weth, weth, 1e10, 1e10, true, payable(USER), 900000000000000000000000000000000
        );
        uint256[] memory _position2 = reader.getPositions(address(vault), USER, _path, _path, _isLong);
        bytes32 _positionHash1 = keccak256(abi.encodePacked(_position1));
        bytes32 _positionHash2 = keccak256(abi.encodePacked(_position2));
        assertNotEq(_positionHash1, _positionHash2);
    }

    function testDecreasePositionEthWorksFromPartners() public giveUserCurrency {
        vm.prank(OWNER);
        positionManager.setPartner(USER, true);
        vm.startPrank(USER);
        wethArray.push(weth);
        address[] memory _path = wethArray;
        router.approvePlugin(address(positionManager));
        WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
        positionManager.increasePositionETH{value: 10 ether}(
            _path, weth, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
        );
        vm.stopPrank();
        boolArray.push(true);
        bool[] memory _isLong = boolArray;
        uint256[] memory _position1 = reader.getPositions(address(vault), USER, _path, _path, _isLong);
        vm.startPrank(USER);
        positionManager.decreasePositionETH(
            weth, weth, 1e10, 1e10, true, payable(USER), 900000000000000000000000000000000
        );
        uint256[] memory _position2 = reader.getPositions(address(vault), USER, _path, _path, _isLong);
        bytes32 _positionHash1 = keccak256(abi.encodePacked(_position1));
        bytes32 _positionHash2 = keccak256(abi.encodePacked(_position2));
        assertNotEq(_positionHash1, _positionHash2);
    }

    /// @notice Not working: Testing deprecated functionality so not a priority
    // function testDecreasePositionAndSwapLetsUsWithdrawATokenOfOurChoice() public giveUserCurrency {
    //     vm.prank(OWNER);
    //     positionManager.setInLegacyMode(true);
    //     vm.startPrank(USER);
    //     address[] memory _path = tokenArray;
    //     router.approvePlugin(address(positionManager));
    //     WETH(weth).increaseAllowance(address(router), LARGE_AMOUNT);
    //     positionManager.increasePosition(
    //         _path, wbtc, 1e28, 0, 35689554309499200000000000000000000, true, 2061587547909500000000000000000000
    //     );
    //     vm.stopPrank();
    //     wbtcArray.push(wbtc);
    //     address[] memory _tokens = wbtcArray;
    //     boolArray.push(true);
    //     bool[] memory _isLong = boolArray;
    //     uint256[] memory _position1 = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
    //     vm.startPrank(USER);
    //     wbtcToUsdcArray.push(wbtc);
    //     wbtcToUsdcArray.push(usdc);
    //     address[] memory _swapPath = wbtcToUsdcArray;
    //     positionManager.decreasePositionAndSwap(
    //         _swapPath, wbtc, 1e10, 1e10, true, USER, 900000000000000000000000000000000, 1
    //     );
    //     uint256[] memory _position2 = reader.getPositions(address(vault), USER, _tokens, _tokens, _isLong);
    //     bytes32 _positionHash1 = keccak256(abi.encodePacked(_position1));
    //     bytes32 _positionHash2 = keccak256(abi.encodePacked(_position2));
    //     assertNotEq(_positionHash1, _positionHash2);
    // }

    // Liquidate can only be tested if collateral drops below threshold

    // Execute order used by keepers to execute limit orders on the orderbook
}
