// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ShortsTrackerTimelock} from "../src/peripherals/ShortsTrackerTimelock.sol";
import {PriceFeedTimelock} from "../src/peripherals/PriceFeedTimelock.sol";
import {RewardTimelock} from "../src/peripherals/RewardTimelock.sol";
import {TokenManager} from "../src/access/TokenManager.sol";
import {ShortsTracker} from "../src/core/ShortsTracker.sol";
import {VaultPriceFeed} from "../src/core/VaultPriceFeed.sol";
import {USDP} from "../src/tokens/USDP.sol";
import {PositionManager} from "../src/core/PositionManager.sol";
import {PositionRouter} from "../src/core/PositionRouter.sol";
import {BRRR} from "../src/core/BRRR.sol";
import {BrrrManager} from "../src/core/BrrrManager.sol";
import {VaultErrorController} from "../src/core/VaultErrorController.sol";
import {ReferralStorage} from "../src/referrals/ReferralStorage.sol";
import {RewardDistributor} from "../src/staking/RewardDistributor.sol";
import {BrrrRewardRouter} from "../src/staking/BrrrRewardRouter.sol";
import {BrrrXpAmplifier} from "../src/staking/BrrrXpAmplifier.sol";
import {RewardTracker} from "../src/staking/RewardTracker.sol";
import {Timelock} from "../src/peripherals/Timelock.sol";

contract DeployP3 is Script {
    HelperConfig public helperConfig;

    ShortsTrackerTimelock public shortsTrackerTimelock;
    PriceFeedTimelock public priceFeedTimelock;
    RewardTimelock public rewardTimelock;
    TokenManager public tokenManager;

    uint256 private deployerKey;

    address[] ownerArray;
    address[] tokenArray; // WETH => WBTC
    uint256[] deltaDiffs;
    uint256[] longSizes;
    uint256[] shortSizes;
    string[] errors;
    address[] brrrArray;
    address OWNER;

    struct Contracts {
        address shortsTracker;
        address vaultPriceFeed;
        address usdp;
        address payable positionManager;
        address payable positionRouter;
        address brrr;
        address brrrManager;
        address vaultErrorController;
        address referralStorage;
        address rewardDistributor;
        address payable rewardRouter;
        address rewardTracker;
        address brrrXpAmplifier;
        address timelock;
    }

    function run(
        Contracts memory contracts,
        address[] memory _signers
    ) external {
        helperConfig = new HelperConfig();

        (,,,,,, deployerKey) = helperConfig.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        OWNER = msg.sender;

        uint256 minSignatures = _signers.length > 2 ? _signers.length - 2 : 1;
        tokenManager = new TokenManager(minSignatures);

        shortsTrackerTimelock = new ShortsTrackerTimelock(OWNER, 1, 300, 20);

        priceFeedTimelock = new PriceFeedTimelock(OWNER, 1, address(tokenManager));

        rewardTimelock =
            new RewardTimelock(OWNER, 1, address(tokenManager), contracts.rewardRouter, contracts.brrrManager, contracts.rewardDistributor);

        // Set Governance
        ShortsTracker(contracts.shortsTracker).setGov(address(shortsTrackerTimelock));
        VaultPriceFeed(contracts.vaultPriceFeed).setGov(address(priceFeedTimelock));
        USDP(contracts.usdp).setGov(contracts.timelock);
        PositionManager(contracts.positionManager).setGov(contracts.timelock);
        PositionRouter(contracts.positionRouter).setGov(contracts.timelock);
        BRRR(contracts.brrr).setGov(contracts.timelock);
        BrrrManager(contracts.brrrManager).setGov(contracts.timelock);
        VaultErrorController(contracts.vaultErrorController).setGov(contracts.timelock);
        ReferralStorage(contracts.referralStorage).setGov(contracts.timelock);
        RewardDistributor(contracts.rewardDistributor).setGov(address(rewardTimelock));
        BrrrRewardRouter(contracts.rewardRouter).setGov(address(rewardTimelock));
        BrrrXpAmplifier(contracts.brrrXpAmplifier).setGov(address(rewardTimelock));

        // Required To Distribute Weekly Rewards
        rewardTimelock.setExternalAdmin(contracts.rewardDistributor, address(rewardTimelock));
        RewardTracker(contracts.rewardTracker).setGov(address(rewardTimelock));

        Timelock(contracts.timelock).setTokenManager(address(tokenManager));

        tokenManager.initialize(_signers);

        vm.stopBroadcast();
    }
}
