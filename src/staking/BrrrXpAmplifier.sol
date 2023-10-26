// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {RewardTracker} from "./RewardTracker.sol";
import {ReentrancyGuard} from "../libraries/utils/ReentrancyGuard.sol";
import {IERC20} from "../libraries/token/IERC20.sol";
import {TransferStakedBrrr} from "./TransferStakedBrrr.sol";
import {Governable} from "../access/Governable.sol";

/// @title BrrrXpAmplifier
/// @dev Contract that allows users to lock LP tokens for a set duration in exchange for XP at various multipliers.
/// @notice Users can still claim rev-share from their reward tokens.
contract BrrrXpAmplifier is Governable, ReentrancyGuard {
    error BrrrXpAmplifier_InvalidTier();
    error BrrrXpAmplifier_InvalidAmount();
    error BrrrXpAmplifier_InsufficientFunds();
    error BrrrXpAmplifier_EmptyPosition();
    error BrrrXpAmplifier_DurationNotFinished();
    error BrrrXpAmplifier_InvalidUser();
    error BrrrXpAmplifier_DurationPastSeasonEnd();
    error BrrrXpAmplifier_SeasonNotOver();
    error BrrrXpAmplifier_NoPositions();
    error BrrrXpAmplifier_InvalidHandler();

    event BrrrXpAmplifier_LiquidityLocked(
        address indexed user, uint256 index, uint256 indexed amount, uint8 indexed tier
    );
    event BrrrXpAmplifier_LiquidityUnlocked(
        address indexed user, uint256 index, uint256 indexed amount, uint8 indexed tier
    );
    event BrrrXpAmplifier_RewardsClaimed(address indexed user, uint256 indexed tokenAmount, uint256 indexed xpAmount);

    RewardTracker public rewardTracker;
    TransferStakedBrrr public stakeTransferrer;

    address public immutable weth;

    struct Position {
        uint256 depositAmount;
        uint8 tier;
        uint256 lockedAt;
        uint256 unlockDate;
        address owner;
        uint256 multiplier; //100 = 1x
    }

    // Address => Index => Position
    mapping(address => mapping(uint256 => Position)) public positions;
    mapping(address => uint256[]) public userPositionIds;
    mapping(address => uint256) public lockedAmount;
    mapping(address => uint256) public totalXpEarned;
    mapping(address => uint256) public averageLockedAmounts;
    mapping(address => uint256) public claimableReward;
    mapping(address => uint256) public previousCumulativeRewardPerToken;
    mapping(address => uint256) public cumulativeRewards;
    mapping(address => uint256) public lastXpUpdate;
    mapping(address => bool) public isHandler;

    uint256 public constant TIER1_DURATION = 1 hours; // Earn XP from BRRR
    uint256 public constant TIER2_DURATION = 30 days; // 1.25x XP multiplier
    uint256 public constant TIER3_DURATION = 90 days; // 1.5x XP multiplier
    uint256 public constant TIER4_DURATION = 180 days; // 2x XP multiplier
    uint256 public constant PRECISION = 10e30;
    // End of Season 1: Sat Jun 01 2024 12:00:00 GMT+0000
    uint256 public constant SEASON_END = 1717243200;

    uint256 public xpPerSecond = 1;
    uint256 public nextPositionId;

    uint256 public cumulativeRewardPerToken;
    uint256 public contractBalance;

    constructor(address _rewardTracker, address _transferStakedBrrr, address _weth) {
        require(_rewardTracker != address(0));
        rewardTracker = RewardTracker(_rewardTracker);
        stakeTransferrer = TransferStakedBrrr(_transferStakedBrrr);
        weth = _weth;
    }

    /// @notice Called by gov after season ends. Users who don't claim before the deadline will have to fill out an application form to claim their rewards.
    /// Used to empty the contract in preparation for the next season or recover wrongly sent tokens.
    /// Should be subject to timelock.
    function recoverTokens(address token) external onlyGov {
        if (
            token == weth && block.timestamp < SEASON_END
                || token == address(rewardTracker) && block.timestamp < SEASON_END
        ) revert BrrrXpAmplifier_SeasonNotOver();
        IERC20(token).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /// @dev Used to temporarily increase rewards during Bonus XP events.
    function updateXpPerSecond(uint256 val) external onlyGov {
        if (val == 0) revert BrrrXpAmplifier_InvalidAmount();
        xpPerSecond = val;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    /// @notice Used to lock RewardTracker tokens for a set durations.
    /// @dev The user must approve the TransferStakedBrrr contract to spend their tokens.
    /// @param tier The tier of the position.
    /// @param amount The amount of tokens to lock.
    function lockLiquidity(uint8 tier, uint256 amount) external {
        if (uint256(tier) > 3) revert BrrrXpAmplifier_InvalidTier();
        if (amount == 0) revert BrrrXpAmplifier_InvalidAmount();
        if (rewardTracker.balanceOf(msg.sender) < amount) revert BrrrXpAmplifier_InsufficientFunds();
        uint256 duration = _getDuration(tier);
        if (block.timestamp + duration > SEASON_END) revert BrrrXpAmplifier_DurationPastSeasonEnd();

        stakeTransferrer.transferFrom(msg.sender, address(this), amount);

        _updateRewards(msg.sender);

        uint256 id = nextPositionId;
        nextPositionId = nextPositionId + 1;

        Position memory newPosition =
            Position(amount, tier, block.timestamp, block.timestamp + duration, msg.sender, _getMultiplier(tier));
        positions[msg.sender][id] = newPosition;
        userPositionIds[msg.sender].push(id);
        lockedAmount[msg.sender] = lockedAmount[msg.sender] + amount;
        contractBalance = contractBalance + amount;

        emit BrrrXpAmplifier_LiquidityLocked(msg.sender, id, amount, tier);
    }

    /// @notice Used to unlock RewardTracker tokens after the set duration has passed.
    /// @param index The index of the position to unlock. Can use getter to find.
    function unlockLiquidity(uint256 index) public {
        Position memory position = positions[msg.sender][index];
        if (position.depositAmount == 0) revert BrrrXpAmplifier_EmptyPosition();
        if (position.unlockDate > block.timestamp) revert BrrrXpAmplifier_DurationNotFinished();
        if (rewardTracker.balanceOf(address(this)) < position.depositAmount) {
            revert BrrrXpAmplifier_InsufficientFunds();
        }
        if (position.owner != msg.sender) revert BrrrXpAmplifier_InvalidUser();

        _updateRewards(msg.sender);

        lockedAmount[msg.sender] = lockedAmount[msg.sender] - position.depositAmount;
        contractBalance = contractBalance - position.depositAmount;
        delete positions[msg.sender][index];
        uint256[] storage userPositions = userPositionIds[msg.sender];
        for (uint256 i = 0; i < userPositions.length; ++i) {
            if (userPositions[i] == index) {
                userPositions[i] = userPositions[userPositions.length - 1];
                userPositions.pop();
                break;
            }
        }

        stakeTransferrer.transfer(msg.sender, position.depositAmount);

        emit BrrrXpAmplifier_LiquidityUnlocked(msg.sender, index, position.depositAmount, position.tier);
    }

    /// @notice Used to unlock all expired positions.
    function unlockAllPositions() external {
        uint256[] memory userPositions = userPositionIds[msg.sender];
        if (userPositions.length == 0) revert BrrrXpAmplifier_NoPositions();
        for (uint256 i = 0; i < userPositions.length; ++i) {
            if (positions[msg.sender][userPositions[i]].unlockDate <= block.timestamp) {
                unlockLiquidity(userPositions[i]);
            }
        }
    }

    /// @notice Used to claim pending WETH/XP rewards accumulated. Callable at any time.
    function claimPendingRewards() external nonReentrant returns (uint256, uint256) {
        return _claimPendingRewards(msg.sender);
    }

    /// @notice Used to claim WETH/XP for a user externally.
    function claimRewardsForAccount(address _account) external nonReentrant returns (uint256, uint256) {
        _validateHandler();
        return _claimPendingRewards(_account);
    }

    /// @notice Returns the amount of claimable WETH rewards.
    /// @param user The address of the user to check.
    function getClaimableTokenRewards(address user) external view returns (uint256) {
        uint256 totalLocked = lockedAmount[user];
        if (totalLocked == 0) {
            return claimableReward[user];
        }
        uint256 bal = contractBalance;
        uint256 pendingRewards = rewardTracker.claimable(address(this)) * PRECISION;
        uint256 nextCumulativeRewardPerToken = cumulativeRewardPerToken + (pendingRewards / bal);
        return claimableReward[user]
            + (totalLocked * (nextCumulativeRewardPerToken - previousCumulativeRewardPerToken[user])) / PRECISION;
    }

    /// @notice Returns the amount of claimable XP rewards.
    /// @param user The address of the user to check.
    function getClaimableXpRewards(address user) external view returns (uint256) {
        return _calculatePendingXpRewards(user);
    }

    /// @notice Returns the amount of time left of a locked position.
    /// @param user The address of the user to check.
    /// @param index The index of the position to check. Can use getter to get values.
    function getRemainingLockDuration(address user, uint256 index) public view returns (uint256) {
        Position memory position = positions[user][index];
        if (position.unlockDate <= block.timestamp) {
            return 0;
        } else {
            return position.unlockDate - block.timestamp;
        }
    }

    /// @notice Getter function for all of a users locked positions.
    /// @param user The address of the user to check.
    function getUserPositionIds(address user) external view returns (uint256[] memory) {
        return userPositionIds[user];
    }

    /// @notice Getter function for a specific locked position.
    /// @param _tier The tiers to check total staked amounts for.
    /// @param _user The address of the user to check.
    function getUserTotalStakedAmountForTier(uint8 _tier, address _user) external view returns (uint256) {
        uint256 total;
        uint256[] memory userPositions = userPositionIds[_user];
        for (uint256 i = 0; i < userPositions.length; ++i) {
            Position memory position = positions[_user][userPositions[i]];
            if (position.tier == _tier) {
                total = total + position.depositAmount;
            }
        }
        return total;
    }

    /// @notice Getter function for a specific locked position.
    /// @param _tier The tiers to check total staked amounts for.
    /// @param _user The address of the user to check.
    function getUserTotalXpEarnedForTier(uint8 _tier, address _user) external view returns (uint256) {
        uint256 totalXp;
        uint256[] memory tokens = userPositionIds[_user];
        uint256 accumulationDuration;
        if (block.timestamp >= SEASON_END) {
            accumulationDuration = SEASON_END - lastXpUpdate[_user];
        } else {
            accumulationDuration = block.timestamp - lastXpUpdate[_user];
        }
        for (uint256 i = 0; i < tokens.length; ++i) {
            Position memory position = positions[_user][tokens[i]];
            if (position.tier == _tier) {
                totalXp =
                    totalXp + (position.depositAmount * position.multiplier * (accumulationDuration * xpPerSecond));
            }
        }
        return totalXp / 100;
    }

    /// @notice Crucial function. Claims WETH from the RewardTracker and updates the contract state.
    /// @dev Adaptation of the RewardTracker's _updateReward function. Essentially collates rewards and divides them up by the same mechanism.
    /// @param _account The address of the user to update.
    function _updateRewards(address _account) private returns (uint256) {
        uint256 blockReward = rewardTracker.claim(address(this));

        uint256 bal = contractBalance;
        uint256 _cumulativeRewardPerToken = cumulativeRewardPerToken;
        if (bal > 0 && blockReward > 0) {
            _cumulativeRewardPerToken = _cumulativeRewardPerToken + ((blockReward * PRECISION) / bal);
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }

        if (_account != address(0)) {
            uint256 totalLocked = lockedAmount[_account];
            uint256 accountReward =
                (totalLocked * (_cumulativeRewardPerToken - previousCumulativeRewardPerToken[_account])) / PRECISION;
            uint256 _claimableReward = claimableReward[_account] + accountReward;

            claimableReward[_account] = _claimableReward;
            previousCumulativeRewardPerToken[_account] = _cumulativeRewardPerToken;

            if (_claimableReward > 0 && lockedAmount[_account] > 0) {
                uint256 nextCumulativeReward = cumulativeRewards[_account] + accountReward;

                averageLockedAmounts[_account] = (
                    (averageLockedAmounts[_account] * cumulativeRewards[_account]) / nextCumulativeReward
                ) + (totalLocked * accountReward) / nextCumulativeReward;

                cumulativeRewards[_account] = nextCumulativeReward;
            }

            uint256 pendingXp = _calculatePendingXpRewards(_account);
            if (pendingXp != 0) {
                lastXpUpdate[_account] = block.timestamp;
                totalXpEarned[_account] = totalXpEarned[_account] + pendingXp;
            }
            return pendingXp;
        }
        return 0;
    }

    function _claimPendingRewards(address _user) internal returns (uint256, uint256) {
        uint256 userXpRewards = _updateRewards(_user);

        uint256 userTokenRewards = claimableReward[_user];
        claimableReward[_user] = 0;

        if (userTokenRewards != 0 && IERC20(weth).balanceOf(address(this)) >= userTokenRewards) {
            IERC20(weth).transfer(_user, userTokenRewards);
        }

        emit BrrrXpAmplifier_RewardsClaimed(_user, userTokenRewards, userXpRewards);
        return (userTokenRewards, userXpRewards);
    }

    /// @notice Returns the duration of a locked position by tier.
    /// @param tier The tier of the position.
    function _getDuration(uint8 tier) private pure returns (uint256) {
        if (tier == 0) {
            return TIER1_DURATION; // 1hr cooldown
        } else if (tier == 1) {
            return TIER2_DURATION; // 30 days
        } else if (tier == 2) {
            return TIER3_DURATION; // 90 days
        } else {
            return TIER4_DURATION; // 180 days
        }
    }

    /// @notice Calculates the amount of XP rewards a user has available to claim.
    /// @dev Users shouldn't be able to earn XP rewards beyond the end of the season.
    /// @param user The address of the user to check.
    function _calculatePendingXpRewards(address user) private view returns (uint256) {
        uint256 totalXp;
        uint256[] memory tokens = userPositionIds[user];
        uint256 accumulationDuration;
        if (block.timestamp >= SEASON_END) {
            accumulationDuration = SEASON_END - lastXpUpdate[user];
        } else {
            accumulationDuration = block.timestamp - lastXpUpdate[user];
        }
        for (uint256 i = 0; i < tokens.length; ++i) {
            Position memory position = positions[user][tokens[i]];
            totalXp = totalXp + (position.depositAmount * position.multiplier * (accumulationDuration * xpPerSecond));
        }
        return totalXp / 100;
    }

    /// @notice Returns the XP multiplier for a given tier.
    /// @param tier The tier of the position.
    function _getMultiplier(uint8 tier) private pure returns (uint256) {
        if (tier == 0) {
            return 100;
        } else if (tier == 1) {
            return 125;
        } else if (tier == 2) {
            return 150;
        } else {
            return 200;
        }
    }

    function _validateHandler() private view {
        if (!isHandler[msg.sender]) {
            revert BrrrXpAmplifier_InvalidHandler();
        }
    }
}
