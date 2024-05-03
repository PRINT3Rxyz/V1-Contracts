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

    address positionRouter = 0x8174Ed4B9e3EEaEC083D8277469B984a2a7d4AF3;
    address positionManager = 0x35DcB942070bcfa58DE5e2A6E2bA596DCEAC440e;
    address fastPriceFeed = 0x9d42214c130E1e4759D1DFdE04B0E4ffFd90c246;
    address shortsTracker = 0xF3A8569fdA26450F11FAf4bB4530C302b4a52Fd6;
    address shortsTrackerTimelock = 0x544Ef343B7CCfc33E45E871966f9e9D80011bA6F;

    address priceKeeper = 0x76A6f07250e4a1Fd2CA6BCC091DdaD337E16DC00;
    address liquidator = 0xcB9818855e820ddfC8eD2130714bA6a54d0F4204;
    address orderKeeper = 0x48dB48C79B69DAFeC150eFB61700C118d035aCC6;
    address globalKeeper = 0x01d51678481C463e0E0aCB1cB388D0c0e2d0Bdf3;

    function run() public {
        vm.startBroadcast();

        IPositionRouter(positionRouter).setPositionKeeper(orderKeeper, true);
        // IPositionRouter(_positionRouter).setAdmin(_keeper);
        IPositionManager(positionManager).setOrderKeeper(orderKeeper, true);
        IPositionManager(positionManager).setLiquidator(liquidator, true);
        // IPositionManager(positionManager).setAdmin(_keeper);
        IFastPriceFeed(fastPriceFeed).setUpdater(priceKeeper, true);
        // IShortsTrackerTimelock(shortsTrackerTimelock).signalSetHandler(shortsTracker, globalKeeper, true);
        // IShortsTrackerTimelock(shortsTrackerTimelock).setHandler(shortsTracker, globalKeeper, true);
        // IShortsTrackerTimelock(shortsTrackerTimelock).setContractHandler(globalKeeper, true);

        vm.stopBroadcast();
    }
}
