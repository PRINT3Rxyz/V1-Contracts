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
import {PositionRouterReader} from "../../../src/peripherals/PositionRouterReader.sol";

contract ReaderTest is Test {
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

    function testReaderSetConfig() public {
        vm.prank(OWNER);
        reader.setConfig(true);
        assertEq(reader.hasMaxGlobalShortSizes(), true);
        vm.prank(OWNER);
        reader.setConfig(false);
        assertEq(reader.hasMaxGlobalShortSizes(), false);
    }

    //////////////////
    // Getter Tests //
    //////////////////

    function testReaderGetMaxAmountIn() public returns (uint256 amount) {
        amount = reader.getMaxAmountIn(vault, weth, wbtc);
        assertNotEq(amount, 0);
    }

    function testReaderGetAmountOut() public view returns (uint256 amountOutAfterFees, uint256 feeAmount) {
        (amountOutAfterFees, feeAmount) = reader.getAmountOut(vault, weth, wbtc, 1e18);
        console.log("Amount out after fees: %s", amountOutAfterFees);
        console.log("Fee amount: %s", feeAmount);
    }

    function testReaderGetFeeBasisPoints()
        public
        returns (uint256 feeBasisPoints, uint256 feeBasisPoints0, uint256 feeBasisPoints1)
    {
        vm.prank(OWNER);
        (feeBasisPoints, feeBasisPoints0, feeBasisPoints1) = reader.getFeeBasisPoints(vault, weth, wbtc, 1e18);
    }

    function testReaderGetFees() public returns (uint256[] memory amounts) {
        amounts = reader.getFees(address(vault), tokenArray);
        assertNotEq(amounts[0], 0);
        assertNotEq(amounts[1], 0);
    }

    function testReaderGetTotalStaked() public returns (uint256[] memory amounts) {
        brrrArray.push(address(brrr));

        amounts = reader.getTotalStaked(brrrArray);
        assertNotEq(amounts[0], 0);
    }

    function testReaderGetStakingInfo() public {
        brrrArray.push(address(rewardTracker));

        vm.expectRevert();
        reader.getStakingInfo(OWNER, brrrArray);
        // Reverts as no yield tracker interfaces to test on
    }

    function testReaderGetPairInfo() public {
        vm.expectRevert();
        reader.getPairInfo(address(vault), tokenArray);
        // Reverts as no factory to test on
    }

    function testReaderGetFundingRates() public view returns (uint256[] memory fundingRates) {
        fundingRates = reader.getFundingRates(address(vault), weth, tokenArray);
    }

    function testReaderGetTokenSupply() public returns (uint256 supply) {
        supply = reader.getTokenSupply(WETH(weth), wethArray);
        assertNotEq(supply, 0);
    }

    function testReaderGetTotalBalance() public giveUserCurrency returns (uint256 balance) {
        ownerArray.push(OWNER);
        ownerArray.push(USER);
        balance = reader.getTotalBalance(WETH(weth), ownerArray);
        assertNotEq(balance, 0);
    }

    function testReaderGetTokenBalances() public returns (uint256[] memory balances) {
        tokenArray.push(usdc);
        balances = reader.getTokenBalances(OWNER, tokenArray);
        assertNotEq(balances[0], 0);
        assertNotEq(balances[1], 0);
        assertNotEq(balances[2], 0);
    }

    function testReaderGetTokenbalancesWithSupplies() public returns (uint256[] memory balances) {
        tokenArray.push(usdc);
        balances = reader.getTokenBalancesWithSupplies(OWNER, tokenArray);
        assertNotEq(balances[0], 0);
        assertNotEq(balances[1], 0);
        assertNotEq(balances[2], 0);
        assertNotEq(balances[3], 0);
        assertNotEq(balances[4], 0);
        assertNotEq(balances[5], 0);
    }

    function testReaderGetPrices() public returns (uint256[] memory amounts) {
        tokenArray.push(usdc);
        amounts = reader.getPrices(priceFeed, tokenArray);
        assertNotEq(amounts[0], 0);
        assertNotEq(amounts[1], 0);
        assertNotEq(amounts[2], 0);
    }

    function testReaderGetVaultTokenInfo() public view returns (uint256[] memory amounts) {
        amounts = reader.getVaultTokenInfo(address(vault), weth, 0, tokenArray);
    }

    function testReaderGetFullVaultTokenInfo() public view returns (uint256[] memory amounts) {
        amounts = reader.getFullVaultTokenInfo(address(vault), weth, 0, tokenArray);
    }

    function testReaderGetFullVaultTokenInfoV2() public view returns (uint256[] memory amounts) {
        amounts = reader.getVaultTokenInfoV2(address(vault), weth, 0, tokenArray);
    }

    function testReaderGetPositions() public returns (uint256[] memory amounts) {
        boolArray.push(true);
        boolArray.push(true);
        amounts = reader.getPositions(address(vault), OWNER, tokenArray, tokenArray, boolArray);
    }
}
