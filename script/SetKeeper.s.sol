// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Script} from "lib/forge-std/src/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {ITimelock} from "../src/peripherals/interfaces/ITimelock.sol";
import {IPriceFeedTimelock} from "../src/peripherals/interfaces/IPriceFeedTimelock.sol";
import {IShortsTrackerTimelock} from "../src/peripherals/interfaces/IShortsTrackerTimelock.sol";
import {IRewardTimelock} from "../src/peripherals/interfaces/IRewardTimelock.sol";
import {IPositionManager} from "../src/core/interfaces/IPositionManager.sol";
import {IPositionRouter} from "../src/core/interfaces/IPositionRouter.sol";
import {IFastPriceFeed} from "../src/oracle/interfaces/IFastPriceFeed.sol";
import {IShortsTracker} from "../src/core/interfaces/IShortsTracker.sol";
import {Types} from "./Types.sol";

contract SetKeeper is Script {
    HelperConfig public helperConfig;
    uint256 private deployerKey;

    function run(
        address _keeper,
        address _positionRouter,
        address _positionManager,
        address _fastPriceFeed,
        address _shortsTracker,
        address _timelock,
        address _priceFeedTimelock,
        address _shortsTrackerTimelock,
        bool _isGovernanceSet,
        bool _isActive
    ) public {
        helperConfig = new HelperConfig();
        Types.NetworkConfig memory networkConfig = helperConfig.getActiveNetworkConfig();

        deployerKey = networkConfig.deployerKey;

        vm.startBroadcast(deployerKey);

        if (_isGovernanceSet) {
            ITimelock(_timelock).govSetKeeper(_positionRouter, _positionManager, _keeper, _isActive);
            IPriceFeedTimelock(_priceFeedTimelock).setPriceFeedUpdater(_fastPriceFeed, _keeper, _isActive);
            IShortsTrackerTimelock(_shortsTrackerTimelock).setHandler(_shortsTracker, _keeper, _isActive);
            IShortsTrackerTimelock(_shortsTrackerTimelock).setContractHandler(_keeper, _isActive);
        } else {
            IPositionRouter(_positionRouter).setPositionKeeper(_keeper, _isActive);
            // IPositionRouter(_positionRouter).setAdmin(_keeper);
            IPositionManager(_positionManager).setOrderKeeper(_keeper, _isActive);
            IPositionManager(_positionManager).setLiquidator(_keeper, _isActive);
            // IPositionManager(_positionManager).setAdmin(_keeper);
            IFastPriceFeed(_fastPriceFeed).setUpdater(_keeper, _isActive);
            IShortsTracker(_shortsTracker).setHandler(_keeper, _isActive);
        }

        vm.stopBroadcast();
    }
}
