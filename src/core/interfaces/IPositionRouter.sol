// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPositionRouter {
    function increasePositionRequestKeys(uint256) external view returns (bytes32);

    function decreasePositionRequestKeys(uint256) external view returns (bytes32);

    function increasePositionRequestKeysStart() external view returns (uint256);

    function decreasePositionRequestKeysStart() external view returns (uint256);

    function increasePositionsIndex(address) external view returns (uint256);

    function decreasePositionsIndex(address) external view returns (uint256);

    function minExecutionFee() external view returns (uint256);

    function minBlockDelayKeeper() external view returns (uint256);

    function minTimeDelayPublic() external view returns (uint256);

    function maxTimeDelay() external view returns (uint256);

    function isLeverageEnabled() external view returns (bool);

    function callbackGasLimit() external view returns (uint256);

    function customCallbackGasLimits(address) external view returns (uint256);

    function isPositionKeeper(address) external view returns (bool);

    function getRequestQueueLengths() external view returns (uint256, uint256, uint256, uint256);

    function getIncreasePositionRequestPath(bytes32 key) external view returns (address[] memory);

    function getDecreasePositionRequestPath(bytes32 key) external view returns (address[] memory);

    function executeIncreasePositions(uint256 endIndex, address executionFeeReceiver) external;

    function executeDecreasePositions(uint256 endIndex, address executionFeeReceiver) external;

    function createIncreasePosition(
        address[] calldata path,
        address indexToken,
        uint256 amountIn,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        bytes32 referralCode,
        address callbackTarget
    ) external payable returns (bytes32);

    function createIncreasePositionETH(
        address[] calldata path,
        address indexToken,
        uint256 minOut,
        uint256 sizeDelta,
        bool isLong,
        uint256 acceptablePrice,
        uint256 executionFee,
        bytes32 referralCode,
        address callbackTarget
    ) external payable returns (bytes32);

    function createDecreasePosition(
        address[] calldata path,
        address indexToken,
        uint256 collateralDelta,
        uint256 sizeDelta,
        bool isLong,
        address receiver,
        uint256 acceptablePrice,
        uint256 minOut,
        uint256 executionFee,
        bool withdrawETH,
        address callbackTarget
    ) external payable returns (bytes32);

    function executeIncreasePosition(bytes32 key, address payable executionFeeReceiver) external returns (bool);

    function cancelIncreasePosition(bytes32 key, address payable executionFeeReceiver) external returns (bool);

    function executeDecreasePosition(bytes32 key, address payable executionFeeReceiver) external returns (bool);

    function cancelDecreasePosition(bytes32 key, address payable executionFeeReceiver) external returns (bool);

    function setPositionKeeper(address account, bool isActive) external;

    function setMinExecutionFee(uint256 minExecutionFee) external;

    function setIsLeverageEnabled(bool isLeverageEnabled) external;

    function setDelayValues(uint256 minBlockDelayKeeper, uint256 minTimeDelayPublic, uint256 maxTimeDelay) external;

    function setRequestKeysStartValues(
        uint256 increasePositionRequestKeysStart,
        uint256 decreasePositionRequestKeysStart
    ) external;

    function setCallbackGasLimit(uint256 callbackGasLimit) external;

    function setCustomCallbackGasLimit(address callbackTarget, uint256 callbackGasLimit) external;
}
