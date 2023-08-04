// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../libraries/token/IERC20.sol";

import "../core/interfaces/IBrrrManager.sol";

import "./interfaces/IRewardTracker.sol";

// provide a way to transfer staked BRRR tokens by unstaking from the sender
// and staking for the receiver
contract TransferStakedBrrr {
    string public constant name = "TransferStakedBrrr";
    string public constant symbol = "tsBRRR";
    uint8 public constant decimals = 18;

    address public brrr;
    IBrrrManager public brrrManager;
    address public stakedBrrrTracker;

    mapping(address => mapping(address => uint256)) public allowances;

    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor(address _brrr, IBrrrManager _brrrManager, address _stakedBrrrTracker) {
        brrr = _brrr;
        brrrManager = _brrrManager;
        stakedBrrrTracker = _stakedBrrrTracker;
    }

    function allowance(address _owner, address _spender) external view returns (uint256) {
        return allowances[_owner][_spender];
    }

    function approve(address _spender, uint256 _amount) external returns (bool) {
        _approve(msg.sender, _spender, _amount);
        return true;
    }

    function transfer(address _recipient, uint256 _amount) external returns (bool) {
        _transfer(msg.sender, _recipient, _amount);
        return true;
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) external returns (bool) {
        uint256 nextAllowance = allowances[_sender][msg.sender] - _amount;
        _approve(_sender, msg.sender, nextAllowance);
        _transfer(_sender, _recipient, _amount);
        return true;
    }

    function balanceOf(address _account) external view returns (uint256) {
        return IRewardTracker(stakedBrrrTracker).depositBalances(_account, brrr);
    }

    function totalSupply() external view returns (uint256) {
        return IERC20(stakedBrrrTracker).totalSupply();
    }

    function _approve(address _owner, address _spender, uint256 _amount) private {
        require(_owner != address(0), "TransferStakedBrrr: approve from the zero address");
        require(_spender != address(0), "TransferStakedBrrr: approve to the zero address");

        allowances[_owner][_spender] = _amount;

        emit Approval(_owner, _spender, _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(_sender != address(0), "TransferStakedBrrr: transfer from the zero address");
        require(_recipient != address(0), "TransferStakedBrrr: transfer to the zero address");

        require(
            brrrManager.lastAddedAt(_sender) + brrrManager.cooldownDuration() <= block.timestamp,
            "TransferStakedBrrr: cooldown duration not yet passed"
        );

        IRewardTracker(stakedBrrrTracker).unstakeForAccount(_sender, brrr, _amount, _sender);

        IRewardTracker(stakedBrrrTracker).stakeForAccount(_sender, _recipient, brrr, _amount);
    }
}
