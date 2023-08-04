// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../libraries/token/ERC20.sol";

/// @notice This is a Mock Token for testing purposes only.
contract WBTC is ERC20 {
    constructor() ERC20("Wrapped BTC", "WBTC") {}

    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 8;
    }
}
