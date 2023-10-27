// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import {IVaultUtils} from "../../core/interfaces/IVaultUtils.sol";

interface ITimelock {
    function marginFeeBasisPoints() external view returns (uint256);

    function maxMarginFeeBasisPoints() external view returns (uint256);

    function shouldToggleIsLeverageEnabled() external view returns (bool);

    function pendingActions(bytes32 action) external view returns (uint256);

    function isHandler(address) external view returns (bool);

    function isKeeper(address) external view returns (bool);

    function buffer() external view returns (uint256);

    function admin() external view returns (address);

    function tokenManager() external view returns (address);

    function mintReceiver() external view returns (address);

    function brrrManager() external view returns (address);

    function maxTokenSupply() external view returns (uint256);

    function setAdmin(address _admin) external;

    function setExternalAdmin(address _target, address _admin) external;

    function setContractHandler(address _handler, bool _isActive) external;

    function initBrrrManager() external;

    function setKeeper(address _keeper, bool _isActive) external;

    function setBuffer(uint256 _buffer) external;

    function setMaxLeverage(address _vault, uint256 _maxLeverage) external;

    function setFundingRate(
        address _vault,
        uint256 _fundingInterval,
        uint256 _fundingRateFactor,
        uint256 _stableFundingRateFactor
    ) external;

    function setShouldToggleIsLeverageEnabled(bool _shouldToggleIsLeverageEnabled) external;

    function setMarginFeeBasisPoints(uint256 _marginFeeBasisPoints, uint256 _maxMarginFeeBasisPoints) external;

    function setSwapFees(
        address _vault,
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints
    ) external;

    function setFees(
        address _vault,
        uint256 _taxBasisPoints,
        uint256 _stableTaxBasisPoints,
        uint256 _mintBurnFeeBasisPoints,
        uint256 _swapFeeBasisPoints,
        uint256 _stableSwapFeeBasisPoints,
        uint256 _marginFeeBasisPoints,
        uint256 _liquidationFeeUsd,
        uint256 _minProfitTime,
        bool _hasDynamicFees
    ) external;

    function enableLeverage(address _vault) external;

    function disableLeverage(address _vault) external;

    function setIsLeverageEnabled(address _vault, bool _isLeverageEnabled) external;

    function setTokenConfig(
        address _vault,
        address _token,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdpAmount,
        uint256 _bufferAmount,
        uint256 _usdpAmount
    ) external;

    function setUsdpAmounts(address _vault, address[] memory _tokens, uint256[] memory _usdpAmounts) external;

    function updateUsdpSupply(uint256 usdpAmount) external;

    function setShortsTrackerAveragePriceWeight(uint256 _shortsTrackerAveragePriceWeight) external;

    function setBrrrCooldownDuration(uint256 _cooldownDuration) external;

    function setMaxGlobalShortSize(address _vault, address _token, uint256 _amount) external;

    function removeAdmin(address _token, address _account) external;

    function setIsSwapEnabled(address _vault, bool _isSwapEnabled) external;

    function setTier(address _referralStorage, uint256 _tierId, uint256 _totalRebate, uint256 _discountShare)
        external;

    function setReferrerTier(address _referralStorage, address _referrer, uint256 _tierId) external;

    function govSetCodeOwner(address _referralStorage, bytes32 _code, address _newAccount) external;

    function setVaultUtils(address _vault, IVaultUtils _vaultUtils) external;

    function setMaxGasPrice(address _vault, uint256 _maxGasPrice) external;

    function withdrawFees(address _vault, address _token, address _receiver) external;

    function batchWithdrawFees(address _vault, address[] memory _tokens) external;

    function setInPrivateLiquidationMode(address _vault, bool _inPrivateLiquidationMode) external;

    function setLiquidator(address _vault, address _liquidator, bool _isActive) external;

    function govSetKeeper(address _positionRouter, address _positionManager, address _keeper, bool _isActive)
        external;

    function setInPrivateTransferMode(address _token, bool _inPrivateTransferMode) external;

    function transferIn(address _sender, address _token, uint256 _amount) external;

    function signalApprove(address _token, address _spender, uint256 _amount) external;

    function approve(address _token, address _spender, uint256 _amount) external;

    function signalWithdrawToken(address _target, address _token, address _receiver, uint256 _amount) external;

    function withdrawToken(address _target, address _token, address _receiver, uint256 _amount) external;

    function signalMint(address _token, address _receiver, uint256 _amount) external;

    function processMint(address _token, address _receiver, uint256 _amount) external;

    function signalSetGov(address _target, address _gov) external;

    function setGov(address _target, address _gov) external;

    function signalSetHandler(address _target, address _handler, bool _isActive) external;

    function setHandler(address _target, address _handler, bool _isActive) external;

    function signalSetPriceFeed(address _vault, address _priceFeed) external;

    function setPriceFeed(address _vault, address _priceFeed) external;

    function signalRedeemUsdp(address _vault, address _token, uint256 _amount) external;

    function redeemUsdp(address _vault, address _token, uint256 _amount) external;

    function signalVaultSetTokenConfig(
        address _vault,
        address _token,
        uint256 _tokenDecimals,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdpAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function vaultSetTokenConfig(
        address _vault,
        address _token,
        uint256 _tokenDecimals,
        uint256 _tokenWeight,
        uint256 _minProfitBps,
        uint256 _maxUsdpAmount,
        bool _isStable,
        bool _isShortable
    ) external;

    function signalVaultClearTokenConfig(address _vault, address _token) external;

    function vaultClearTokenConfig(address _vault, address _token) external;

    function cancelAction(bytes32 _action) external;
}
