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
import {TokenManager} from "../../../src/access/TokenManager.sol";

contract TokenManagerTest is Test {
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
    TokenManager tokenManager;

    address public wbtc;
    address payable weth;
    address public usdc;

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

        tokenManager = new TokenManager(1);
        ownerArray.push(OWNER);
        tokenManager.initialize(ownerArray);

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
        vm.stopPrank();
        _;
    }

    //////////////////
    // Setter Tests //
    /////////////////

    function testTokenManagerDoesntAllowDoubleInitialization() public {
        ownerArray.push(OWNER);
        vm.prank(OWNER);
        vm.expectRevert();
        tokenManager.initialize(ownerArray);
    }

    function testTokenManagerSignalSignAndSetAdmin() public {
        vm.startPrank(OWNER);
        tokenManager.signalSetAdmin(address(tokenManager), USER);
        vm.expectRevert();
        tokenManager.signSetAdmin(address(tokenManager), USER, 1);
        vm.expectRevert();
        tokenManager.setAdmin(address(tokenManager), USER, 1);
        vm.stopPrank();
    }

    function testTokenManagerSignalSignAndSetGov() public {
        vm.startPrank(OWNER);
        tokenManager.signalSetGov(address(timelock), address(tokenManager), USER);
        vm.expectRevert();
        tokenManager.signSetGov(address(timelock), address(tokenManager), USER, 1);
        vm.expectRevert();
        tokenManager.setGov(address(timelock), address(tokenManager), USER, 1);
        vm.stopPrank();
    }

    ///////////////////
    // Getter Tests //
    //////////////////

    function testTokenManagerGetSignersLength() public {
        uint256 len = tokenManager.signersLength();
        assertEq(len, 1);
    }

    ////////////////////
    // Function Tests //
    ////////////////////

    function testTokenManagerSignalAndApprove() public {
        vm.startPrank(OWNER);
        WETH(weth).transfer(address(tokenManager), 1e18);
        tokenManager.signalApprove(weth, USER, 1e18);
        vm.warp(block.timestamp + 1);
        vm.roll(block.number + 1);
        tokenManager.signApprove(weth, USER, 1e18, 1);
        tokenManager.approve(weth, USER, 1e18, 1);
        vm.stopPrank();
        uint256 balBefore = WETH(weth).balanceOf(USER);
        vm.prank(USER);
        WETH(weth).transferFrom(address(tokenManager), USER, 1e18);
        uint256 balAfter = WETH(weth).balanceOf(USER);
        assertEq(balAfter - balBefore, 1e18);
    }

    // Need mock ERC721 to test
    function testTokenManagerSignalSignAndApproveNFT() public {
        vm.expectRevert();
        tokenManager.signalApproveNFT(weth, USER, 1);
        vm.expectRevert();
        tokenManager.signApproveNFT(weth, USER, 1, 1);
        vm.expectRevert();
        tokenManager.approveNFT(weth, USER, 1, 1);
    }

    // Need mock ERC721 to test
    function testTokenManagerSignalSignAndApproveNFTs() public {
        vm.expectRevert();
        tokenManager.signalApproveNFTs(weth, USER, numberArray);
        vm.expectRevert();
        tokenManager.signApproveNFTs(weth, USER, numberArray, 1);
        vm.expectRevert();
        tokenManager.approveNFTs(weth, USER, numberArray, 1);
    }

    function testTokenManagerReceiveNFTs() public {
        vm.expectRevert();
        tokenManager.receiveNFTs(weth, USER, numberArray);
    }
}
