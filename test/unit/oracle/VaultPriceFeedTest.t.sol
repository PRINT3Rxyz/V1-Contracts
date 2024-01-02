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

contract VaultPriceFeedTest is Test {
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
    function testVaultPriceFeedSetGov() public {
        vm.prank(OWNER);
        priceFeed.setGov(USER);
        assertEq(priceFeed.gov(), USER);
    }

    function testVaultPriceFeedSetAdjustment() public {
        vm.warp(block.timestamp + 1e10);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        priceFeed.setAdjustment(weth, true, 10);
        assertEq(priceFeed.adjustmentBasisPoints(weth), 10);
    }

    function testVaultPriceFeedSetUseV2Pricing() public {
        vm.prank(OWNER);
        priceFeed.setUseV2Pricing(true);
        assertTrue(priceFeed.useV2Pricing());
    }

    function testVaultPriceFeedSetIsAmmEnabled() public {
        vm.prank(OWNER);
        priceFeed.setIsAmmEnabled(true);
        assertTrue(priceFeed.isAmmEnabled());
    }

    function testVaultPriceFeedSetIsSecondaryPriceEnabled() public {
        vm.prank(OWNER);
        priceFeed.setIsSecondaryPriceEnabled(true);
        assertTrue(priceFeed.isSecondaryPriceEnabled());
    }

    function testVaultPriceFeedSetTokens() public {
        vm.prank(OWNER);
        priceFeed.setTokens(weth, wbtc, usdc);
        assertEq(priceFeed.btc(), weth);
        assertEq(priceFeed.eth(), wbtc);
        assertEq(priceFeed.bnb(), usdc);
    }

    function testVaultPriceFeedSetPairs() public {
        vm.prank(OWNER);
        priceFeed.setPairs(weth, wbtc, usdc);
        assertEq(priceFeed.bnbBusd(), weth);
        assertEq(priceFeed.ethBnb(), wbtc);
        assertEq(priceFeed.btcBnb(), usdc);
    }

    function testVaultPriceFeedSetSpreadBasisPoints(uint256 _bps) public {
        vm.assume(_bps <= priceFeed.MAX_SPREAD_BASIS_POINTS());
        vm.prank(OWNER);
        priceFeed.setSpreadBasisPoints(weth, _bps);
        assertEq(priceFeed.spreadBasisPoints(weth), _bps);
    }

    function testVaultPriceFeedSetSpreadThresholdBasisPoints(uint256 _bps) public {
        vm.prank(OWNER);
        priceFeed.setSpreadThresholdBasisPoints(_bps);
        assertEq(priceFeed.spreadThresholdBasisPoints(), _bps);
    }

    function testVaultPriceFeedSetFavourPrimaryPrice() public {
        vm.prank(OWNER);
        priceFeed.setFavorPrimaryPrice(true);
        assertTrue(priceFeed.favorPrimaryPrice());
    }

    function testVaultPriceFeedSetPriceSampleSpace(uint256 _sampleSpace) public {
        vm.assume(_sampleSpace > 0);
        vm.prank(OWNER);
        priceFeed.setPriceSampleSpace(_sampleSpace);
        assertEq(priceFeed.priceSampleSpace(), _sampleSpace);
    }

    function testVaultPriceFeedSetMaxStrictPriceDeviation(uint256 _maxDeviation) public {
        vm.prank(OWNER);
        priceFeed.setMaxStrictPriceDeviation(_maxDeviation);
        assertEq(priceFeed.maxStrictPriceDeviation(), _maxDeviation);
    }

    function testVaultPriceFeedSetTokenConfig() public {
        Token newUsdc = new Token();
        vm.prank(OWNER);
        priceFeed.setTokenConfig(address(newUsdc), usdcPriceFeed, 8, true);
        assertEq(priceFeed.priceFeeds(address(newUsdc)), usdcPriceFeed);
        assertEq(priceFeed.priceDecimals(address(newUsdc)), 8);
        assertEq(priceFeed.strictStableTokens(address(newUsdc)), true);
    }

    //////////////////
    // Getter Tests //
    //////////////////
    function testVaultPriceFeedGetPrice()
        public
        view
        returns (uint256 maxPrice, uint256 minPrice, uint256 ammPrice, uint256 swapPrice)
    {
        maxPrice = priceFeed.getPrice(weth, true, false, false);
        minPrice = priceFeed.getPrice(weth, false, false, false);
        ammPrice = priceFeed.getPrice(weth, false, true, false);
        swapPrice = priceFeed.getPrice(weth, false, false, true);
    }

    function testVaultPriceFeedGetPriceV1()
        public
        view
        returns (uint256 maxPrice, uint256 minPrice, uint256 ammPrice)
    {
        maxPrice = priceFeed.getPriceV1(weth, true, false);
        minPrice = priceFeed.getPriceV1(weth, false, false);
        ammPrice = priceFeed.getPriceV1(weth, false, true);
    }

    function testVaultPriceFeedGetPriceV2()
        public
        view
        returns (uint256 maxPrice, uint256 minPrice, uint256 ammPrice)
    {
        maxPrice = priceFeed.getPriceV2(weth, true, false);
        minPrice = priceFeed.getPriceV2(weth, false, false);
        ammPrice = priceFeed.getPriceV2(weth, false, true);
    }

    function testVaultPriceFeedGetAmmPriceV2() public view returns (uint256 maxPrice, uint256 minPrice) {
        maxPrice = priceFeed.getAmmPriceV2(weth, true, 2e11);
        minPrice = priceFeed.getAmmPriceV2(weth, false, 2e11);
    }

    function testVaultPriceFeedGetLatestPrimaryPrice() public view returns (uint256 price) {
        price = priceFeed.getLatestPrimaryPrice(weth);
    }

    function testVaultPriceFeedGetPrimaryPrice() public view returns (uint256 maxPrice, uint256 minPrice) {
        maxPrice = priceFeed.getPrimaryPrice(weth, true);
        minPrice = priceFeed.getPrimaryPrice(weth, false);
    }

    function testVaultPriceFeedGetSecondaryPrice() public view returns (uint256 maxPrice, uint256 minPrice) {
        maxPrice = priceFeed.getSecondaryPrice(weth, 2e11, true);
        minPrice = priceFeed.getSecondaryPrice(weth, 2e11, false);
    }

    function testVaultPriceFeedGetAmmPrice() public view returns (uint256 ammPrice) {
        ammPrice = priceFeed.getAmmPrice(weth);
    }

    function testVaultPriceFeedGetPairPrice() public returns (uint256 pairPrice1, uint256 pairPrice2) {
        vm.expectRevert(); // Pair not set
        pairPrice1 = priceFeed.getPairPrice(weth, true);
        vm.expectRevert(); // Pair not set
        pairPrice2 = priceFeed.getPairPrice(weth, false);
    }
}
