// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../libraries/token/IERC20.sol";

import "../core/interfaces/IBrrrManager.sol";

import "./interfaces/IRewardTracker.sol";

import "../access/Governable.sol";

// provide a way to migrate staked BRRR tokens by unstaking from the sender
// and staking for the receiver
// meant for a one-time use for a specified sender
// requires the contract to be added as a handler
contract StakedBrrrMigrator is Governable {
    address public sender;
    address public brrr;
    address public stakedBrrrTracker;
    bool public isEnabled = true;

    constructor(address _sender, address _brrr, address _stakedBrrrTracker) {
        sender = _sender;
        brrr = _brrr;
        stakedBrrrTracker = _stakedBrrrTracker;
    }

    function disable() external onlyGov {
        isEnabled = false;
    }

    function transfer(address _recipient, uint256 _amount) external onlyGov {
        _transfer(sender, _recipient, _amount);
    }

    function _transfer(address _sender, address _recipient, uint256 _amount) private {
        require(isEnabled, "StakedBrrrMigrator: not enabled");
        require(_sender != address(0), "StakedBrrrMigrator: transfer from the zero address");
        require(_recipient != address(0), "StakedBrrrMigrator: transfer to the zero address");

        IRewardTracker(stakedBrrrTracker).unstakeForAccount(_sender, brrr, _amount, _sender);

        IRewardTracker(stakedBrrrTracker).stakeForAccount(_sender, _recipient, brrr, _amount);
    }
}
