// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "forge-std/Script.sol";
import {IVault} from "../src/core/interfaces/IVault.sol";
import {ITimelock} from "../src/peripherals/interfaces/ITimelock.sol";

contract SetTokenConfig is Script {

    function run(address _timelock, address _vault, address _token, uint256 _tokenWeight) public {
        uint256 usdpAmount = IVault(_vault).usdpAmounts(_token);
        uint256 bufferAmount = (IVault(_vault).poolAmounts(_token) * 85) / 100;
        ITimelock(_timelock).setTokenConfig(_vault, _token, _tokenWeight, 0, 0, bufferAmount, usdpAmount);
    }

}