// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

// Need the address for BrrrXPAmplifier and RewardTracker
// call BrrrXPAmplifier.claimPendingRewards
// call RewardTracker.claim
// might need to use claimForAccount instead of claim for Reward Tracker
import {IBrrrXpAmplifier} from "./interfaces/IBrrrXpAmplifier.sol";
import {IRewardTracker} from "./interfaces/IRewardTracker.sol";

/// @dev Needs to have isHandler set to true by:
/// 1. RewardTracker
/// 2. BrrrXPAmplifier

contract RewardClaimer {

    event RewardsClaimed(address indexed user, uint256 indexed tokenAmount, uint256 indexed xpAmount);

    IBrrrXpAmplifier public immutable brrrXpAmplifier;
    IRewardTracker public immutable rewardTracker;

    constructor(IBrrrXpAmplifier _amplifier, IRewardTracker _tracker) {
        brrrXpAmplifier = _amplifier;
        rewardTracker = _tracker;
    }

    function claimAllPendingRewards(address _receiver) external returns (uint256, uint256) {
        uint256 stakedRewards = rewardTracker.claimForAccount(msg.sender, _receiver);
        (uint256 lockedRewards, uint256 xpRewards) = brrrXpAmplifier.claimRewardsForAccount(msg.sender);
        emit RewardsClaimed(msg.sender, stakedRewards + lockedRewards, xpRewards);
        return (stakedRewards + lockedRewards, xpRewards);
    }

}