// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";
import "../libraries/utils/Address.sol";

import "./interfaces/IRewardTracker.sol";
import "./interfaces/IBrrrRewardRouter.sol";
import "../tokens/interfaces/IMintable.sol";
import "../tokens/interfaces/IWETH.sol";
import "../core/interfaces/IBrrrManager.sol";
import "../access/Governable.sol";

contract BrrrRewardRouter is IBrrrRewardRouter, ReentrancyGuard, Governable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    bool public isInitialized;

    address public weth;

    address public brrr; // PRINT3R Liquidity Provider token

    address public override stakedBrrrTracker;

    address public brrrManager;

    event StakeBrrr(address account, uint256 amount);
    event UnstakeBrrr(address account, uint256 amount);

    receive() external payable {
        require(msg.sender == weth, "Router: invalid sender");
    }

    function initialize(address _weth, address _brrr, address _stakedBrrrTracker, address _brrrManager)
        external
        override
        onlyGov
    {
        require(!isInitialized, "RewardRouter: already initialized");
        isInitialized = true;
        weth = _weth;
        brrr = _brrr;
        stakedBrrrTracker = _stakedBrrrTracker;
        brrrManager = _brrrManager;
    }

    function withdrawToken(address _token, address _account, uint256 _amount) external override onlyGov {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    function mintAndStakeBrrr(address _token, uint256 _amount, uint256 _minUsdg, uint256 _minBrrr)
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(_amount > 0, "RewardRouter: invalid _amount");

        address account = msg.sender;
        uint256 brrrAmount =
            IBrrrManager(brrrManager).addLiquidityForAccount(account, account, _token, _amount, _minUsdg, _minBrrr);
        IRewardTracker(stakedBrrrTracker).stakeForAccount(account, account, brrr, brrrAmount);

        emit StakeBrrr(account, brrrAmount);

        return brrrAmount;
    }

    function mintAndStakeBrrrETH(uint256 _minUsdg, uint256 _minBrrr)
        external
        payable
        override
        nonReentrant
        returns (uint256)
    {
        require(msg.value > 0, "RewardRouter: invalid msg.value");

        IWETH(weth).deposit{value: msg.value}();
        IERC20(weth).approve(brrrManager, msg.value);

        address account = msg.sender;
        uint256 brrrAmount = IBrrrManager(brrrManager).addLiquidityForAccount(
            address(this), account, weth, msg.value, _minUsdg, _minBrrr
        );

        IRewardTracker(stakedBrrrTracker).stakeForAccount(account, account, brrr, brrrAmount);

        emit StakeBrrr(account, brrrAmount);

        return brrrAmount;
    }

    function unstakeAndRedeemBrrr(address _tokenOut, uint256 _brrrAmount, uint256 _minOut, address _receiver)
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(_brrrAmount > 0, "RewardRouter: invalid _brrrAmount");

        address account = msg.sender;
        IRewardTracker(stakedBrrrTracker).unstakeForAccount(account, brrr, _brrrAmount, account);
        uint256 amountOut =
            IBrrrManager(brrrManager).removeLiquidityForAccount(account, _tokenOut, _brrrAmount, _minOut, _receiver);

        emit UnstakeBrrr(account, _brrrAmount);

        return amountOut;
    }

    function unstakeAndRedeemBrrrETH(uint256 _brrrAmount, uint256 _minOut, address payable _receiver)
        external
        override
        nonReentrant
        returns (uint256)
    {
        require(_brrrAmount > 0, "RewardRouter: invalid _brrrAmount");

        address account = msg.sender;
        IRewardTracker(stakedBrrrTracker).unstakeForAccount(account, brrr, _brrrAmount, account);
        uint256 amountOut =
            IBrrrManager(brrrManager).removeLiquidityForAccount(account, weth, _brrrAmount, _minOut, address(this));

        IWETH(weth).withdraw(amountOut);

        _receiver.sendValue(amountOut);

        emit UnstakeBrrr(account, _brrrAmount);

        return amountOut;
    }

    function claim() external override nonReentrant {
        address account = msg.sender;
        IRewardTracker(stakedBrrrTracker).claimForAccount(account, account);
    }

    function handleRewards(bool _shouldConvertWethToEth) external override nonReentrant {
        address account = msg.sender;

        if (_shouldConvertWethToEth) {
            uint256 wethAmount = IRewardTracker(stakedBrrrTracker).claimForAccount(account, address(this));
            IWETH(weth).withdraw(wethAmount);

            payable(account).sendValue(wethAmount);
        } else {
            IRewardTracker(stakedBrrrTracker).claimForAccount(account, account);
        }
    }
}
