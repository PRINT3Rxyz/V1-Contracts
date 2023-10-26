// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IPositionManager {
    function setOrderKeeper(address _account, bool _isActive) external;
    function setLiquidator(address _account, bool _isActive) external;
    function setPartner(address _account, bool _isActive) external;
    function setInLegacyMode(bool _inLegacyMode) external;
    function setShouldValidateIncreaseOrder(bool _shouldValidateIncreaseOrder) external;

    function increasePosition(
        address[] memory _path,
        address _indexToken,
        uint256 _amountIn,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external;

    function increasePositionETH(
        address[] memory _path,
        address _indexToken,
        uint256 _minOut,
        uint256 _sizeDelta,
        bool _isLong,
        uint256 _price
    ) external payable;

    function decreasePosition(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price
    ) external;

    function decreasePositionETH(
        address _collateralToken,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price
    ) external;

    function decreasePositionAndSwap(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address _receiver,
        uint256 _price,
        uint256 _minOut
    ) external;

    function decreasePositionAndSwapETH(
        address[] memory _path,
        address _indexToken,
        uint256 _collateralDelta,
        uint256 _sizeDelta,
        bool _isLong,
        address payable _receiver,
        uint256 _price,
        uint256 _minOut
    ) external;

    function liquidatePosition(
        address _account,
        address _collateralToken,
        address _indexToken,
        bool _isLong,
        address _feeReceiver
    ) external;

    function executeSwapOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeIncreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
    function executeDecreaseOrder(address _account, uint256 _orderIndex, address payable _feeReceiver) external;
}
