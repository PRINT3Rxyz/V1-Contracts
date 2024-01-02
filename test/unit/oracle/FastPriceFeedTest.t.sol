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

contract FastPriceFeedTest is Test {
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
    function testFastPriceFeedCantBeInitializedTwice() public {
        vm.prank(OWNER);
        vm.expectRevert();
        fastPriceFeed.initialize(1, ownerArray, ownerArray);
    }

    function testFastPriceFeedSetSigner() public {
        vm.prank(OWNER);
        fastPriceFeed.setSigner(USER, true);
        assertEq(fastPriceFeed.isSigner(USER), true);
    }

    function testFastPriceFeedSetUpdater() public {
        vm.prank(OWNER);
        fastPriceFeed.setUpdater(USER, true);
        assertEq(fastPriceFeed.isUpdater(USER), true);
    }

    function testFastPriceFeedSetVaultPriceFeed() public {
        vm.prank(OWNER);
        fastPriceFeed.setVaultPriceFeed(USER);
        assertEq(fastPriceFeed.vaultPriceFeed(), USER);
    }

    function testFastPriceFeedSetMaxTimeDeviation(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setMaxTimeDeviation(_num);
        assertEq(fastPriceFeed.maxTimeDeviation(), _num);
    }

    function testFastPriceFeedSetPriceDuration(uint256 _num) public {
        vm.assume(_num <= fastPriceFeed.MAX_PRICE_DURATION());
        vm.prank(OWNER);
        fastPriceFeed.setPriceDuration(_num);
        assertEq(fastPriceFeed.priceDuration(), _num);
    }

    function testFastPriceFeedSetMaxPriceUpdateDelay(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setMaxPriceUpdateDelay(_num);
        assertEq(fastPriceFeed.maxPriceUpdateDelay(), _num);
    }

    function testFastPriceFeedSetSpreadBasisPointsIfInactive(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setSpreadBasisPointsIfInactive(_num);
        assertEq(fastPriceFeed.spreadBasisPointsIfInactive(), _num);
    }

    function testFastPriceFeedSetSpreadBasisPointsIfChainError(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setSpreadBasisPointsIfChainError(_num);
        assertEq(fastPriceFeed.spreadBasisPointsIfChainError(), _num);
    }

    function testFastPriceFeedSetMinBlockInterval(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setMinBlockInterval(_num);
        assertEq(fastPriceFeed.minBlockInterval(), _num);
    }

    function testFastPriceFeedSetIsSpreadEnabled() public {
        vm.startPrank(OWNER);
        fastPriceFeed.setIsSpreadEnabled(true);
        assertEq(fastPriceFeed.isSpreadEnabled(), true);
        fastPriceFeed.setIsSpreadEnabled(false);
        assertEq(fastPriceFeed.isSpreadEnabled(), false);
        vm.stopPrank();
    }

    function testFastPriceFeedSetLastUpdatedAt(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setLastUpdatedAt(_num);
        assertEq(fastPriceFeed.lastUpdatedAt(), _num);
    }

    function testFastPriceFeedSetTokenManager() public {
        vm.prank(OWNER);
        fastPriceFeed.setTokenManager(USER);
        assertEq(fastPriceFeed.tokenManager(), USER);
    }

    function testFastPriceFeedSetMaxDeviationBasisPoints(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setMaxDeviationBasisPoints(_num);
        assertEq(fastPriceFeed.maxDeviationBasisPoints(), _num);
    }

    function testFastPriceFeedSetMaxCumulativeDeltaDiffs(uint256 _num) public {
        tokenArray.push(usdc);
        numberArray.push(_num);
        numberArray.push(_num);
        numberArray.push(_num);
        vm.prank(OWNER);
        fastPriceFeed.setMaxCumulativeDeltaDiffs(tokenArray, numberArray);
        assertEq(fastPriceFeed.maxCumulativeDeltaDiffs(weth), _num);
        assertEq(fastPriceFeed.maxCumulativeDeltaDiffs(wbtc), _num);
        assertEq(fastPriceFeed.maxCumulativeDeltaDiffs(usdc), _num);
    }

    function testFastPriceFeedSetPriceDataInterval(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setPriceDataInterval(_num);
        assertEq(fastPriceFeed.priceDataInterval(), _num);
    }

    function testFastPriceFeedSetMinAuthorizations(uint256 _num) public {
        vm.prank(OWNER);
        fastPriceFeed.setMinAuthorizations(_num);
        assertEq(fastPriceFeed.minAuthorizations(), _num);
    }

    function testFastPriceFeedSetTokens() public {
        Token token = new Token();
        Token token2 = new Token();
        Token token3 = new Token();
        address[] memory _tokens = new address[](3);
        _tokens[0] = address(token);
        _tokens[1] = address(token2);
        _tokens[2] = address(token3);
        numberArray.push(10 ** 6);
        numberArray.push(10 ** 7);
        numberArray.push(10 ** 8);
        vm.prank(OWNER);
        fastPriceFeed.setTokens(_tokens, numberArray);
        assertEq(fastPriceFeed.tokens(0), address(token));
        assertEq(fastPriceFeed.tokens(1), address(token2));
        assertEq(fastPriceFeed.tokens(2), address(token3));
        assertEq(fastPriceFeed.tokenPrecisions(0), 10 ** 6);
        assertEq(fastPriceFeed.tokenPrecisions(1), 10 ** 7);
        assertEq(fastPriceFeed.tokenPrecisions(2), 10 ** 8);
    }

    function testFastPriceFeedSetPrices() public {
        // On anvil block.timestamp defaults to 0. This will result in arithmetic overflow, so must warp/roll.
        vm.warp(block.timestamp + 1e10);
        vm.roll(block.number + 1);
        numberArray.push(1e8);
        numberArray.push(1e8);
        vm.startPrank(OWNER);
        fastPriceFeed.setPrices(tokenArray, numberArray, block.timestamp);
        vm.stopPrank();
        assertEq(fastPriceFeed.prices(weth), 1e8);
        assertEq(fastPriceFeed.prices(wbtc), 1e8);
    }

    function testFastPriceFeedSetCompactedPrices() public {
        numberArray.push(1e8);
        numberArray.push(1e8);
        vm.prank(OWNER);
        fastPriceFeed.setTokens(tokenArray, numberArray);
        uint256 WETH_price = 1e8;
        uint256 WBTC_price = 1e8;

        // Shift WBTC_price 32 bits to the left
        WBTC_price = WBTC_price << 32;

        // Combine WETH_price and WBTC_price
        uint256 priceBitArrayElement = WETH_price | WBTC_price;

        // Add priceBitArrayElement to _priceBitArray
        uint256[] memory _priceBitArray = new uint256[](1);
        _priceBitArray[0] = priceBitArrayElement;

        vm.warp(block.timestamp + 1e10);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        fastPriceFeed.setCompactedPrices(_priceBitArray, block.timestamp);
        uint256 adjustedPrice = (1e8 * 10 ** 30) / 1e8;
        assertEq(fastPriceFeed.prices(weth), adjustedPrice);
        assertEq(fastPriceFeed.prices(wbtc), adjustedPrice);
    }

    function testFastPriceFeedSetPricesWithBits() public {
        numberArray.push(1e8);
        numberArray.push(1e8);
        vm.prank(OWNER);
        fastPriceFeed.setTokens(tokenArray, numberArray);
        uint256 WETH_price = 1e8;
        uint256 WBTC_price = 1e8;

        // Shift WBTC_price 32 bits to the left
        WBTC_price = WBTC_price << 32;

        // Combine WETH_price and WBTC_price
        uint256 priceBit = WETH_price | WBTC_price;
        vm.warp(block.timestamp + 1e10);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        fastPriceFeed.setPricesWithBits(priceBit, block.timestamp);
        uint256 adjustedPrice = (1e8 * 10 ** 30) / 1e8;
        assertEq(fastPriceFeed.prices(weth), adjustedPrice);
        assertEq(fastPriceFeed.prices(wbtc), adjustedPrice);
    }

    function testFastPriceFeedSetPricesWithBitsAndExecute() public {
        numberArray.push(1e8);
        numberArray.push(1e8);
        vm.prank(OWNER);
        fastPriceFeed.setTokens(tokenArray, numberArray);
        uint256 WETH_price = 1e8;
        uint256 WBTC_price = 1e8;

        // Shift WBTC_price 32 bits to the left
        WBTC_price = WBTC_price << 32;

        // Combine WETH_price and WBTC_price
        uint256 priceBit = WETH_price | WBTC_price;
        vm.warp(block.timestamp + 1e10);
        vm.roll(block.number + 1);
        vm.prank(OWNER);
        fastPriceFeed.setPricesWithBitsAndExecute(address(positionRouter), priceBit, block.timestamp, 0, 0, 0, 0);
    }

    function testFastPriceFeedDisableFastPrice() public {
        vm.prank(OWNER);
        fastPriceFeed.disableFastPrice();
        bool fastPriceFavoured = fastPriceFeed.favorFastPrice(weth);
        assertFalse(fastPriceFavoured);
    }

    function testFastPriceFeedEnableFastPrice() public {
        vm.startPrank(OWNER);
        fastPriceFeed.disableFastPrice();
        bool fastPriceEnabled1 = fastPriceFeed.favorFastPrice(weth);
        assertFalse(fastPriceEnabled1);
        fastPriceFeed.enableFastPrice();
        bool fastPriceEnabled2 = fastPriceFeed.favorFastPrice(weth);
        assertTrue(fastPriceEnabled2);
        vm.stopPrank();
    }

    //////////////////
    // Getter Tests //
    //////////////////
    function testFastPriceFeedGetPriceData() public {
        (uint256 refPrice, uint256 refTime, uint256 cumulativeRefDelta, uint256 cumulativeFastDelta) =
            fastPriceFeed.getPriceData(weth);
        assertEq(refPrice, 0);
        assertEq(refTime, 0);
        assertEq(cumulativeRefDelta, 0);
        assertEq(cumulativeFastDelta, 0);
    }
}
