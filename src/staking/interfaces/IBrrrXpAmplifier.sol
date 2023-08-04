// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IBrrrXpAmplifier {
    event BrrrXpAmplifier_LiquidityLocked(address indexed user, uint256 indexed index, uint256 indexed amount);
    event BrrrXpAmplifier_LiquidityUnlocked(address indexed user, uint256 indexed index);
    event BrrrXpAmplifier_RewardsClaimed(address indexed user, uint256 indexed tokenAmount, uint256 indexed xpAmount);

    struct Position {
        uint256 depositAmount;
        uint8 tier;
        uint256 lockedAt;
        uint256 unlockDate;
        address owner;
        uint256 multiplier; //100 = 1x
    }

    function rewardTracker() external view returns (address);
    function stakeTransferrer() external view returns (address);
    function weth() external view returns (address);
    function positions(address user, uint256 index) external view returns (Position memory);
    function userPositionIds(address user) external view returns (uint256[] memory);
    function lockedAmount(address user) external view returns (uint256);
    function totalXpEarned(address user) external view returns (uint256);
    function claimableReward(address user) external view returns (uint256);
    function cumulativeRewards(address user) external view returns (uint256);
    function xpPerSecond() external view returns (uint256);
    function gov() external view returns (address);

    function setGov(address newGov) external;
    function recoverTokens(address token) external;
    function updateXpPerSecond(uint256 val) external;
    function lockLiquidity(uint8 tier, uint256 amount) external;
    function unlockLiquidity(uint256 index) external;
    function claimPendingRewards(address user) external;
    function getClaimableTokenRewards(address user) external view returns (uint256);
    function getClaimableXpRewards(address user) external view returns (uint256);
    function getRemainingLockDuration(address user, uint256 index) external view returns (uint256);
    function getUserPositionIds(address user) external view returns (uint256[] memory);
}
