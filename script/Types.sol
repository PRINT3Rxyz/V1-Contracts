// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {HelperConfig} from "./HelperConfig.s.sol";
import {VaultPriceFeed} from "../src/core/VaultPriceFeed.sol";
import {FastPriceEvents} from "../src/oracle/FastPriceEvents.sol";
import {FastPriceFeed} from "../src/oracle/FastPriceFeed.sol";
import {Vault} from "../src/core/Vault.sol";
import {USDP} from "../src/tokens/USDP.sol";
import {Router} from "../src/core/Router.sol";
import {VaultUtils} from "../src/core/VaultUtils.sol";
import {ShortsTracker} from "../src/core/ShortsTracker.sol";
import {PositionManager} from "../src/core/PositionManager.sol";
import {PositionRouter} from "../src/core/PositionRouter.sol";
import {OrderBook} from "../src/core/OrderBook.sol";
import {BRRR} from "../src/core/BRRR.sol";
import {BrrrManager} from "../src/core/BrrrManager.sol";
import {VaultErrorController} from "../src/core/VaultErrorController.sol";
import {ReferralStorage} from "../src/referrals/ReferralStorage.sol";
import {BrrrRewardRouter} from "../src/staking/BrrrRewardRouter.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";
import {RewardDistributor} from "../src/staking/RewardDistributor.sol";
import {ReferralReader} from "../src/referrals/ReferralReader.sol";
import {Timelock} from "../src/peripherals/Timelock.sol";
import {OrderBookReader} from "../src/peripherals/OrderBookReader.sol";
import {VaultReader} from "../src/peripherals/VaultReader.sol";
import {RewardReader} from "../src/peripherals/RewardReader.sol";
import {TransferStakedBrrr} from "../src/staking/TransferStakedBrrr.sol";
import {BrrrBalance} from "../src/staking/BrrrBalance.sol";
import {Reader} from "../src/peripherals/Reader.sol";
import {BrrrXpAmplifier} from "../src/staking/BrrrXpAmplifier.sol";
import {ShortsTrackerTimelock} from "../src/peripherals/ShortsTrackerTimelock.sol";
import {RewardClaimer} from "../src/staking/RewardClaimer.sol";
import {PriceFeedTimelock} from "../src/peripherals/PriceFeedTimelock.sol";
import {RewardTimelock} from "../src/peripherals/RewardTimelock.sol";
import {TokenManager} from "../src/access/TokenManager.sol";

library Types {
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address usdcPriceFeed;
        address payable weth;
        address wbtc;
        address usdc;
        uint256 deployerKey;
        address deployer;
    }

    struct Core {
        BrrrManager brrrManager;
        BRRR brrr;
        Vault vault;
        VaultUtils vaultUtils;
        VaultPriceFeed vaultPriceFeed;
        VaultErrorController vaultErrorController;
        ShortsTracker shortsTracker;
        PositionManager positionManager;
        PositionRouter positionRouter;
        OrderBook orderBook;
        Router router;
    }

    struct Oracle {
        FastPriceFeed fastPriceFeed;
        FastPriceEvents fastPriceEvents;
    }

    struct Referral {
        ReferralStorage referralStorage;
        ReferralReader referralReader;
    }

    struct Staking {
        BrrrRewardRouter brrrRewardRouter;
        RewardTracker rewardTracker;
        RewardDistributor rewardDistributor;
        TransferStakedBrrr transferStakedBrrr;
        BrrrBalance brrrBalance;
        BrrrXpAmplifier brrrXpAmplifier;
        RewardClaimer rewardClaimer;
    }

    struct Peripherals {
        Timelock timelock;
        OrderBookReader orderBookReader;
        VaultReader vaultReader;
        RewardReader rewardReader;
        Reader reader;
        ShortsTrackerTimelock shortsTrackerTimelock;
        PriceFeedTimelock priceFeedTimelock;
        RewardTimelock rewardTimelock;
    }

    struct Tokens {
        USDP usdp;
        address wbtc;
        address payable weth;
        address usdc;
    }

    struct Contracts {
        Core core;
        Oracle oracle;
        Referral referral;
        Staking staking;
        Peripherals peripherals;
        Tokens tokens;
        NetworkConfig networkConfig;
    }
}
