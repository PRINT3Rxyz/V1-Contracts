// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
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

contract FastPriceFeedTest is Test {
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

        brrrManager = new BrrrManager(address(vault), address(usdp), address(brrr), address(shortsTracker), 900);

        vaultErrorController = new VaultErrorController();

        WBTC(wbtc).mint(OWNER, LARGE_AMOUNT);
        WETH(weth).deposit{value: LARGE_AMOUNT}();
        Token(usdc).mint(OWNER, LARGE_AMOUNT);

        referralStorage = new ReferralStorage();

        rewardRouter = new BrrrRewardRouter();

        rewardTracker = new RewardTracker("Staked BRRR", "sBRRR");

        rewardDistributor = new RewardDistributor(weth, address(rewardTracker));

        timelock = new Timelock(OWNER, 1, OWNER, OWNER, address(brrrManager), address(rewardRouter), 0, 10, 500);

        transferStakedBrrr = new TransferStakedBrrr(address(brrr), brrrManager, address(rewardTracker));

        brrrBalance = new BrrrBalance(brrrManager, address(rewardTracker));

        orderBookReader = new OrderBookReader();

        vaultReader = new VaultReader();

        rewardReader = new RewardReader();

        referralReader = new ReferralReader();

        reader = new Reader();

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
        vault.setFees(15, 5, 15, 15, 1, 10, 2000000000000000000000000000000, 86400, true);
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
        rewardTracker.setHandler(address(rewardRouter), true);

        rewardDistributor.updateLastDistributionTime();
        rewardDistributor.setTokensPerInterval(4670965608460);

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
