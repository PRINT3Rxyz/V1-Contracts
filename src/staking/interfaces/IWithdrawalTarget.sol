// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IWithdrawalTarget {
    function withdrawToken(address _token, address _account, uint256 _amount) external;
}
