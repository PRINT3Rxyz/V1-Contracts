// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ITimelock} from "../src/peripherals/interfaces/ITimelock.sol";
import {IPriceFeedTimelock} from "../src/peripherals/interfaces/IPriceFeedTimelock.sol";
import {IShortsTrackerTimelock} from "../src/peripherals/interfaces/IShortsTrackerTimelock.sol";
import {IRewardTimelock} from "../src/peripherals/interfaces/IRewardTimelock.sol";

contract SetKeeper is Script {
    HelperConfig public helperConfig;

    function run() public {
        helperConfig = new HelperConfig();
        (,,,,,, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        vm.startBroadcast(deployerKey);

        /*
            Assuming Governance Contracts are Set, Process is:
              1. ITimelock(_timelock).govSetKeeper(_keeper, _isActive);
              2. IPriceFeedTimelock(_priceFeedTimelock).setPriceFeedUpdater(_fastPriceFeed, _updater, _isActive);
              3. IShortsTrackerTimelock(_shortsTrackerTimelock).setHandler(_shortsTracker, _handler, _isActive);
        */

        /*
            If Governance Contracts are not Set, Process is:
              1. PositionRouter.setPositionKeeper(_keeper, _isActive);
              2. PositionManager.setOrderKeeper(_keeper, _isActive);
              3. PositionManagber.setLiquidator(_liquidator, _isActive);
              4. FastPriceFeed.setUpdater(_updater, _isActive);
              5. ShortsTracker.setHandler(_handler, _isActive);
        */

        vm.stopBroadcast();
    }
}
