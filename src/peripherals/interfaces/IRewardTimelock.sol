// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IRewardTimelock {
    function setAdmin(address _admin) external;
    function setTokenManager(address _tokenManager) external;
    function setExternalAdmin(address _target, address _admin) external;
    function setContractHandler(address _handler, bool _isActive) external;
    function setKeeper(address _keeper, bool _isActive) external;
    function setBuffer(uint256 _buffer) external;
    function transferIn(address _sender, address _token, uint256 _amount) external;
    function signalApprove(address _token, address _spender, uint256 _amount) external;
    function approve(address _token, address _spender, uint256 _amount) external;
    function signalSetGov(address _target, address _gov) external;
    function setGov(address _target, address _gov) external;
    function signalSetHandler(address _target, address _handler, bool _isActive) external;
    function setHandler(address _target, address _handler, bool _isActive) external;
    function signalRecoverTokens(address _token, address _target) external;
    function recoverTokens(address _token, address _target) external;
    function signalUpdateXpPerSecond(uint256 _value, address _target) external;
    function updateXpPerSecond(uint256 _value, address _target) external;
    function setDistributorRewards(address _target, uint256 _tokensPerInterval) external;
    function signalSetPrivacy(
        address _target,
        bool __inPrivateTransferMode,
        bool _inPrivateStakingMode,
        bool _inPrivateClaimingMode
    ) external;
    function setPrivacy(
        address _target,
        bool __inPrivateTransferMode,
        bool _inPrivateStakingMode,
        bool _inPrivateClaimingMode
    ) external;
    function signalWithdrawal(address _target, address _token, address _account, uint256 _amount) external;
    function withdrawTokens(address _target, address _token, address _account, uint256 _amount) external;
    function cancelAction(bytes32 _action) external;
}
