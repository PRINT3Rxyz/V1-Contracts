// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

contract Governable {
    address public gov;

    constructor() {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        require(_gov != address(0), "Governable: _gov is zero address");
        gov = _gov;
    }
}
