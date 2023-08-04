// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../tokens/MintableBaseToken.sol";

contract BRRR is MintableBaseToken {
    constructor() MintableBaseToken("BRRR", "BRRR", 0) {}

    function id() external pure returns (string memory _name) {
        return "BRRR";
    }
}
