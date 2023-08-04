// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./IVault.sol";

interface IBrrrManager {
    function brrr() external view returns (address);
    function usdp() external view returns (address);
    function vault() external view returns (IVault);
    function cooldownDuration() external returns (uint256);
    function getAumInUsdp(bool maximise) external view returns (uint256);
    function lastAddedAt(address _account) external returns (uint256);
    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdp, uint256 _minBrrr)
        external
        returns (uint256);
    function addLiquidityForAccount(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _minUsdp,
        uint256 _minBrrr
    ) external returns (uint256);
    function removeLiquidity(address _tokenOut, uint256 _brrrAmount, uint256 _minOut, address _receiver)
        external
        returns (uint256);
    function removeLiquidityForAccount(
        address _account,
        address _tokenOut,
        uint256 _brrrAmount,
        uint256 _minOut,
        address _receiver
    ) external returns (uint256);
    function setShortsTrackerAveragePriceWeight(uint256 _shortsTrackerAveragePriceWeight) external;
    function setCooldownDuration(uint256 _cooldownDuration) external;
}
