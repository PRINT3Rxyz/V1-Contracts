// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {ITimelockTarget} from "./interfaces/ITimelockTarget.sol";
import {IHandlerTarget} from "./interfaces/IHandlerTarget.sol";
import {IAdmin} from "../access/interfaces/IAdmin.sol";
import {IBrrrRewardRouter} from "../staking/interfaces/IBrrrRewardRouter.sol";
import {IBrrrXpAmplifier} from "../staking/interfaces/IBrrrXpAmplifier.sol";
import {IRewardDistributor} from "../staking/interfaces/IRewardDistributor.sol";
import {IRewardTracker} from "../staking/interfaces/IRewardTracker.sol";
import {IWithdrawalTarget} from "../staking/interfaces/IWithdrawalTarget.sol";

import {IERC20} from "../libraries/token/IERC20.sol";

/*
    @dev Governance contract for the following contracts:
    - BrrrRewardRouter
    - BrrrXpAmplifier
    - RewardDistributor
    - RewardTracker
*/

contract RewardTimelock {
    uint256 public constant MAX_BUFFER = 5 days;

    uint256 public buffer;
    address public admin;

    address public tokenManager;
    address public rewardRouter;
    address public brrrManager;
    address public rewardDistributor;

    mapping(bytes32 => uint256) public pendingActions;

    mapping(address => bool) public isHandler;
    mapping(address => bool) public isKeeper;

    event SignalPendingAction(bytes32 action);
    event SignalApprove(address token, address spender, uint256 amount, bytes32 action);
    event SignalSetGov(address target, address gov, bytes32 action);
    event SignalSetHandler(address target, address handler, bool isActive, bytes32 action);
    event SignalRecoverTokens(address target, address token, bytes32 action);
    event SignalUpdateXpPerSecond(address target, uint256 value, bytes32 action);
    event SignalSetPrivacy(
        address target,
        bool inPrivateTransferMode,
        bool inPrivateStakingMode,
        bool inPrivateClaimingMode,
        bytes32 action
    );
    event ClearAction(bytes32 action);

    modifier onlyAdmin() {
        require(msg.sender == admin, "RewardTimelock: forbidden");
        _;
    }

    modifier onlyHandlerAndAbove() {
        require(msg.sender == admin || isHandler[msg.sender], "RewardTimelock: forbidden");
        _;
    }

    modifier onlyKeeperAndAbove() {
        require(msg.sender == admin || isHandler[msg.sender] || isKeeper[msg.sender], "Timelock: forbidden");
        _;
    }

    modifier onlyTokenManager() {
        require(msg.sender == tokenManager, "RewardTimelock: forbidden");
        _;
    }

    constructor(
        address _admin,
        uint256 _buffer,
        address _tokenManager,
        address _brrrManager,
        address _rewardRouter,
        address _rewardDistributor
    ) {
        require(_buffer <= MAX_BUFFER, "RewardTimelock: invalid _buffer");
        admin = _admin;
        buffer = _buffer;
        tokenManager = _tokenManager;
        rewardRouter = _rewardRouter;
        brrrManager = _brrrManager;
        rewardDistributor = _rewardDistributor;
    }

    function setAdmin(address _admin) external onlyTokenManager {
        admin = _admin;
    }

    function setTokenManager(address _tokenManager) external onlyTokenManager {
        tokenManager = _tokenManager;
    }

    function setExternalAdmin(address _target, address _admin) external onlyAdmin {
        require(_target != address(this), "RewardTimelock: invalid _target");
        IAdmin(_target).setAdmin(_admin);
    }

    function setContractHandler(address _handler, bool _isActive) external onlyAdmin {
        isHandler[_handler] = _isActive;
    }

    function setKeeper(address _keeper, bool _isActive) external onlyAdmin {
        isKeeper[_keeper] = _isActive;
    }

    function setBuffer(uint256 _buffer) external onlyAdmin {
        require(_buffer <= MAX_BUFFER, "RewardTimelock: invalid _buffer");
        require(_buffer > buffer, "RewardTimelock: buffer cannot be decreased");
        buffer = _buffer;
    }

    function transferIn(address _sender, address _token, uint256 _amount) external onlyAdmin {
        IERC20(_token).transferFrom(_sender, address(this), _amount);
    }

    function signalApprove(address _token, address _spender, uint256 _amount) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("approve", _token, _spender, _amount));
        _setPendingAction(action);
        emit SignalApprove(_token, _spender, _amount, action);
    }

    function approve(address _token, address _spender, uint256 _amount) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("approve", _token, _spender, _amount));
        _validateAction(action);
        _clearAction(action);
        IERC20(_token).approve(_spender, _amount);
    }

    function signalSetGov(address _target, address _gov) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("setGov", _target, _gov));
        _setPendingAction(action);
        emit SignalSetGov(_target, _gov, action);
    }

    function setGov(address _target, address _gov) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("setGov", _target, _gov));
        _validateAction(action);
        _clearAction(action);
        ITimelockTarget(_target).setGov(_gov);
    }

    function signalSetHandler(address _target, address _handler, bool _isActive) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("setHandler", _target, _handler, _isActive));
        _setPendingAction(action);
        emit SignalSetHandler(_target, _handler, _isActive, action);
    }

    function setHandler(address _target, address _handler, bool _isActive) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("setHandler", _target, _handler, _isActive));
        _validateAction(action);
        _clearAction(action);
        IHandlerTarget(_target).setHandler(_handler, _isActive);
    }

    function signalRecoverTokens(address _token, address _target) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("recoverTokens", _token, _target));
        _setPendingAction(action);
        emit SignalRecoverTokens(_token, _target, action);
    }

    function recoverTokens(address _token, address _target) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("recoverTokens", _token, _target));
        _validateAction(action);
        _clearAction(action);
        IBrrrXpAmplifier(_target).recoverTokens(_token);
    }

    function signalUpdateXpPerSecond(uint256 _value, address _target) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("updateXpPerSecond", _value, _target));
        _setPendingAction(action);
        emit SignalUpdateXpPerSecond(_target, _value, action);
    }

    function updateXpPerSecond(uint256 _value, address _target) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("updateXpPerSecond", _value, _target));
        _validateAction(action);
        _clearAction(action);
        IBrrrXpAmplifier(_target).updateXpPerSecond(_value);
    }

    /// @notice No signal structure -> Needs instant finality
    /// @dev Requires Admin Role on RewardDistributor Contract
    function setDistributorRewards(address _target, uint256 _tokensPerInterval) external onlyAdmin {
        IRewardDistributor(_target).updateLastDistributionTime();
        IRewardDistributor(_target).setTokensPerInterval(_tokensPerInterval);
    }

    function signalSetPrivacy(
        address _target,
        bool __inPrivateTransferMode,
        bool _inPrivateStakingMode,
        bool _inPrivateClaimingMode
    ) external onlyAdmin {
        bytes32 action = keccak256(
            abi.encodePacked(
                "setPrivacy", _target, __inPrivateTransferMode, _inPrivateStakingMode, _inPrivateClaimingMode
            )
        );
        _setPendingAction(action);
        emit SignalSetPrivacy(_target, __inPrivateTransferMode, _inPrivateStakingMode, _inPrivateClaimingMode, action);
    }

    function setPrivacy(
        address _target,
        bool __inPrivateTransferMode,
        bool _inPrivateStakingMode,
        bool _inPrivateClaimingMode
    ) external onlyAdmin {
        bytes32 action = keccak256(
            abi.encodePacked(
                "setPrivacy", _target, __inPrivateTransferMode, _inPrivateStakingMode, _inPrivateClaimingMode
            )
        );
        _validateAction(action);
        _clearAction(action);
        IRewardTracker(_target).setInPrivateTransferMode(__inPrivateTransferMode);
        IRewardTracker(_target).setInPrivateStakingMode(_inPrivateStakingMode);
        IRewardTracker(_target).setInPrivateClaimingMode(_inPrivateClaimingMode);
    }

    function signalWithdrawal(address _target, address _token, address _account, uint256 _amount) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("withdrawal", _target, _token, _account, _amount));
        _setPendingAction(action);
        emit SignalRecoverTokens(_target, _token, action);
    }

    function withdrawTokens(address _target, address _token, address _account, uint256 _amount) external onlyAdmin {
        bytes32 action = keccak256(abi.encodePacked("withdrawal", _target, _token, _account, _amount));
        _validateAction(action);
        _clearAction(action);
        IWithdrawalTarget(_target).withdrawToken(_token, _account, _amount);
    }

    function cancelAction(bytes32 _action) external onlyAdmin {
        _clearAction(_action);
    }

    function _setPendingAction(bytes32 _action) private {
        require(pendingActions[_action] == 0, "RewardTimelock: action already signalled");
        pendingActions[_action] = block.timestamp + buffer;
        emit SignalPendingAction(_action);
    }

    function _validateAction(bytes32 _action) private view {
        require(pendingActions[_action] != 0, "RewardTimelock: action not signalled");
        require(pendingActions[_action] < block.timestamp, "RewardTimelock: action time not yet passed");
    }

    function _clearAction(bytes32 _action) private {
        require(pendingActions[_action] != 0, "RewardTimelock: invalid _action");
        delete pendingActions[_action];
        emit ClearAction(_action);
    }
}
