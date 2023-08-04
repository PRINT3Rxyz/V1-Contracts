// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

interface IBrrrRewardRouter {
    function stakedBrrrTracker() external view returns (address);
    function initialize(address _weth, address _brrr, address _stakedBrrrTracker, address _brrrManager) external;

    function withdrawToken(address _token, address _account, uint256 _amount) external;

    function mintAndStakeBrrr(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minBrrr)
        external
        returns (uint256);

    function mintAndStakeBrrrETH(uint256 _minUsdg, uint256 _minBrrr) external payable returns (uint256);

    function unstakeAndRedeemBrrr(address _tokenOut, uint256 _brrrAmount, uint256 _minOut, address _receiver)
        external
        returns (uint256);

    function unstakeAndRedeemBrrrETH(uint256 _brrrAmount, uint256 _minOut, address payable _receiver)
        external
        returns (uint256);

    function claim() external;

    function handleRewards(bool _shouldConvertWethToEth) external;
}
