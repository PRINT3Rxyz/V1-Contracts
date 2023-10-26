// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

interface IPriceFeedTimelock {
    function setAdmin(address _admin) external;
    function setExternalAdmin(address _target, address _admin) external;
    function setContractHandler(address _handler, bool _isActive) external;
    function setKeeper(address _keeper, bool _isActive) external;
    function setBuffer(uint256 _buffer) external;
    function setIsAmmEnabled(address _priceFeed, bool _isEnabled) external;
    function setIsSecondaryPriceEnabled(address _priceFeed, bool _isEnabled) external;
    function setMaxStrictPriceDeviation(address _priceFeed, uint256 _maxStrictPriceDeviation) external;
    function setUseV2Pricing(address _priceFeed, bool _useV2Pricing) external;
    function setAdjustment(address _priceFeed, address _token, bool _isAdditive, uint256 _adjustmentBps) external;
    function setSpreadBasisPoints(address _priceFeed, address _token, uint256 _spreadBasisPoints) external;
    function setPriceSampleSpace(address _priceFeed, uint256 _priceSampleSpace) external;
    function setVaultPriceFeed(address _fastPriceFeed, address _vaultPriceFeed) external;
    function setPriceDuration(address _fastPriceFeed, uint256 _priceDuration) external;
    function setMaxPriceUpdateDelay(address _fastPriceFeed, uint256 _maxPriceUpdateDelay) external;
    function setSpreadBasisPointsIfInactive(address _fastPriceFeed, uint256 _spreadBasisPointsIfInactive) external;
    function setSpreadBasisPointsIfChainError(address _fastPriceFeed, uint256 _spreadBasisPointsIfChainError)
        external;
    function setMinBlockInterval(address _fastPriceFeed, uint256 _minBlockInterval) external;
    function setIsSpreadEnabled(address _fastPriceFeed, bool _isSpreadEnabled) external;
    function transferIn(address _sender, address _token, uint256 _amount) external;
    function signalApprove(address _token, address _spender, uint256 _amount) external;
    function approve(address _token, address _spender, uint256 _amount) external;
    function signalWithdrawToken(address _target, address _token, address _receiver, uint256 _amount) external;
    function withdrawToken(address _target, address _token, address _receiver, uint256 _amount) external;
    function signalSetGov(address _target, address _gov) external;
    function setGov(address _target, address _gov) external;
    function signalSetPriceFeedWatcher(address _fastPriceFeed, address _account, bool _isActive) external;
    function setPriceFeedWatcher(address _fastPriceFeed, address _account, bool _isActive) external;
    function signalSetPriceFeedUpdater(address _fastPriceFeed, address _account, bool _isActive) external;
    function setPriceFeedUpdater(address _fastPriceFeed, address _account, bool _isActive) external;
    function signalPriceFeedSetTokenConfig(
        address _vaultPriceFeed,
        address _token,
        address _priceFeed,
        uint256 _priceDecimals,
        bool _isStrictStable
    ) external;
    function priceFeedSetTokenConfig(
        address _vaultPriceFeed,
        address _token,
        address _priceFeed,
        uint256 _priceDecimals,
        bool _isStrictStable
    ) external;
    function cancelAction(bytes32 _action) external;
}
