// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IShortsTrackerTimelock {
    function setBuffer(uint256 _buffer) external;
    function signalSetAdmin(address _admin) external;
    function setAdmin(address _admin) external;
    function setContractHandler(address _handler, bool _isActive) external;
    function signalSetGov(address _shortsTracker, address _gov) external;
    function setGov(address _shortsTracker, address _gov) external;
    function signalSetHandler(address _target, address _handler, bool _isActive) external;
    function setHandler(address _target, address _handler, bool _isActive) external;
    function signalSetAveragePriceUpdateDelay(uint256 _averagePriceUpdateDelay) external;
    function setAveragePriceUpdateDelay(uint256 _averagePriceUpdateDelay) external;
    function signalSetMaxAveragePriceChange(uint256 _maxAveragePriceChange) external;
    function setMaxAveragePriceChange(uint256 _maxAveragePriceChange) external;
    function signalSetIsGlobalShortDataReady(address _shortsTracker, bool _value) external;
    function setIsGlobalShortDataReady(address _shortsTracker, bool _value) external;
    function disableIsGlobalShortDataReady(address _shortsTracker) external;
    function setGlobalShortAveragePrices(
        address _shortsTracker,
        address[] calldata _tokens,
        uint256[] calldata _averagePrices
    ) external;
    function cancelAction(bytes32 _action) external;
}
