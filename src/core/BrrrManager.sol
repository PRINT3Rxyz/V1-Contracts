// SPDX-License-Identifier: MIT

import "../libraries/token/IERC20.sol";
import "../libraries/token/SafeERC20.sol";
import "../libraries/utils/ReentrancyGuard.sol";

import "./interfaces/IVault.sol";
import "./interfaces/IBrrrManager.sol";
import "./interfaces/IShortsTracker.sol";
import "../tokens/interfaces/IUSDP.sol";
import "../tokens/interfaces/IMintable.sol";
import "../access/Governable.sol";

pragma solidity 0.8.18;

contract BrrrManager is ReentrancyGuard, Governable, IBrrrManager {
    using SafeERC20 for IERC20;

    uint256 public constant PRICE_PRECISION = 10 ** 30;
    uint256 public constant USDP_DECIMALS = 18;
    uint256 public constant BRRR_PRECISION = 10 ** 18;
    uint256 public constant MAX_COOLDOWN_DURATION = 48 hours;
    uint256 public constant BASIS_POINTS_DIVISOR = 10000;

    IVault public override vault;
    IShortsTracker public shortsTracker;
    address public override usdp;
    address public override brrr;

    uint256 public override cooldownDuration;
    mapping(address => uint256) public override lastAddedAt;

    uint256 public aumAddition;
    uint256 public aumDeduction;

    bool public inPrivateMode;
    uint256 public shortsTrackerAveragePriceWeight;
    mapping(address => bool) public isHandler;

    event AddLiquidity(
        address account,
        address token,
        uint256 amount,
        uint256 aumInUsdp,
        uint256 brrrSupply,
        uint256 usdpAmount,
        uint256 mintAmount
    );

    event RemoveLiquidity(
        address account,
        address token,
        uint256 brrrAmount,
        uint256 aumInUsdp,
        uint256 brrrSupply,
        uint256 usdpAmount,
        uint256 amountOut
    );

    constructor(address _vault, address _usdp, address _brrr, address _shortsTracker, uint256 _cooldownDuration) {
        gov = msg.sender;
        vault = IVault(_vault);
        usdp = _usdp;
        brrr = _brrr;
        shortsTracker = IShortsTracker(_shortsTracker);
        cooldownDuration = _cooldownDuration;
    }

    function setInPrivateMode(bool _inPrivateMode) external onlyGov {
        inPrivateMode = _inPrivateMode;
    }

    function setShortsTracker(IShortsTracker _shortsTracker) external onlyGov {
        shortsTracker = _shortsTracker;
    }

    function setShortsTrackerAveragePriceWeight(uint256 _shortsTrackerAveragePriceWeight) external override onlyGov {
        require(shortsTrackerAveragePriceWeight <= BASIS_POINTS_DIVISOR, "BrrrManager: invalid weight");
        shortsTrackerAveragePriceWeight = _shortsTrackerAveragePriceWeight;
    }

    function setHandler(address _handler, bool _isActive) external onlyGov {
        isHandler[_handler] = _isActive;
    }

    function setCooldownDuration(uint256 _cooldownDuration) external override onlyGov {
        require(_cooldownDuration <= MAX_COOLDOWN_DURATION, "BrrrManager: invalid _cooldownDuration");
        cooldownDuration = _cooldownDuration;
    }

    function setAumAdjustment(uint256 _aumAddition, uint256 _aumDeduction) external onlyGov {
        aumAddition = _aumAddition;
        aumDeduction = _aumDeduction;
    }

    function addLiquidity(address _token, uint256 _amount, uint256 _minUsdp, uint256 _minBrrr)
        external
        override
        nonReentrant
        returns (uint256)
    {
        if (inPrivateMode) revert("BrrrManager: action not enabled");
        return _addLiquidity(msg.sender, msg.sender, _token, _amount, _minUsdp, _minBrrr);
    }

    function addLiquidityForAccount(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _minUsdp,
        uint256 _minBrrr
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _addLiquidity(_fundingAccount, _account, _token, _amount, _minUsdp, _minBrrr);
    }

    function removeLiquidity(address _tokenOut, uint256 _brrrAmount, uint256 _minOut, address _receiver)
        external
        override
        nonReentrant
        returns (uint256)
    {
        if (inPrivateMode) revert("BrrrManager: action not enabled");
        return _removeLiquidity(msg.sender, _tokenOut, _brrrAmount, _minOut, _receiver);
    }

    function removeLiquidityForAccount(
        address _account,
        address _tokenOut,
        uint256 _brrrAmount,
        uint256 _minOut,
        address _receiver
    ) external override nonReentrant returns (uint256) {
        _validateHandler();
        return _removeLiquidity(_account, _tokenOut, _brrrAmount, _minOut, _receiver);
    }

    function getPrice(bool _maximise) external view returns (uint256) {
        uint256 aum = getAum(_maximise);
        uint256 supply = IERC20(brrr).totalSupply();
        return (aum * BRRR_PRECISION) / supply;
    }

    function getAums() public view returns (uint256[] memory) {
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = getAum(true);
        amounts[1] = getAum(false);
        return amounts;
    }

    function getAumInUsdp(bool maximise) public view override returns (uint256) {
        uint256 aum = getAum(maximise);
        return (aum * (10 ** USDP_DECIMALS)) / PRICE_PRECISION;
    }

    function getAum(bool maximise) public view returns (uint256) {
        uint256 length = vault.allWhitelistedTokensLength();
        uint256 aum = aumAddition;
        uint256 shortProfits = 0;
        IVault _vault = vault;

        for (uint256 i = 0; i < length; i++) {
            address token = vault.allWhitelistedTokens(i);
            bool isWhitelisted = vault.whitelistedTokens(token);

            if (!isWhitelisted) {
                continue;
            }

            uint256 price = maximise ? _vault.getMaxPrice(token) : _vault.getMinPrice(token);
            uint256 poolAmount = _vault.poolAmounts(token);
            uint256 decimals = _vault.tokenDecimals(token);

            if (_vault.stableTokens(token)) {
                aum = aum + ((poolAmount * price) / (10 ** decimals));
            } else {
                // add global short profit / loss
                uint256 size = _vault.globalShortSizes(token);

                if (size > 0) {
                    (uint256 delta, bool hasProfit) = getGlobalShortDelta(token, price, size);
                    if (!hasProfit) {
                        // add losses from shorts
                        aum = aum + delta;
                    } else {
                        shortProfits = shortProfits + delta;
                    }
                }

                aum = (aum + (_vault.guaranteedUsd(token)));

                uint256 reservedAmount = _vault.reservedAmounts(token);
                aum = aum + (((poolAmount - reservedAmount) * price) / (10 ** decimals));
            }
        }

        aum = shortProfits > aum ? 0 : aum - shortProfits;
        return aumDeduction > aum ? 0 : aum - aumDeduction;
    }

    function getGlobalShortDelta(address _token, uint256 _price, uint256 _size) public view returns (uint256, bool) {
        uint256 averagePrice = getGlobalShortAveragePrice(_token);
        uint256 priceDelta = averagePrice > _price ? averagePrice - _price : _price - averagePrice;
        uint256 delta = (_size * priceDelta) / averagePrice;
        return (delta, averagePrice > _price);
    }

    function getGlobalShortAveragePrice(address _token) public view returns (uint256) {
        IShortsTracker _shortsTracker = shortsTracker;
        if (address(_shortsTracker) == address(0) || !_shortsTracker.isGlobalShortDataReady()) {
            return vault.globalShortAveragePrices(_token);
        }

        uint256 _shortsTrackerAveragePriceWeight = shortsTrackerAveragePriceWeight;
        if (_shortsTrackerAveragePriceWeight == 0) {
            return vault.globalShortAveragePrices(_token);
        } else if (_shortsTrackerAveragePriceWeight == BASIS_POINTS_DIVISOR) {
            return _shortsTracker.globalShortAveragePrices(_token);
        }

        uint256 vaultAveragePrice = vault.globalShortAveragePrices(_token);
        uint256 shortsTrackerAveragePrice = _shortsTracker.globalShortAveragePrices(_token);

        return (
            (vaultAveragePrice * (BASIS_POINTS_DIVISOR - _shortsTrackerAveragePriceWeight))
                + (shortsTrackerAveragePrice * _shortsTrackerAveragePriceWeight)
        ) / BASIS_POINTS_DIVISOR;
    }

    function _addLiquidity(
        address _fundingAccount,
        address _account,
        address _token,
        uint256 _amount,
        uint256 _minUsdp,
        uint256 _minBrrr
    ) private returns (uint256) {
        require(_amount > 0, "BrrrManager: invalid _amount");

        // calculate aum before buyUSDP
        uint256 aumInUsdp = getAumInUsdp(true);
        uint256 brrrSupply = IERC20(brrr).totalSupply();

        IERC20(_token).safeTransferFrom(_fundingAccount, address(vault), _amount);
        uint256 usdpAmount = vault.buyUSDP(_token, address(this));
        require(usdpAmount >= _minUsdp, "BrrrManager: insufficient USDP output");

        uint256 mintAmount = aumInUsdp == 0 ? usdpAmount : (usdpAmount * brrrSupply) / aumInUsdp;
        require(mintAmount >= _minBrrr, "BrrrManager: insufficient BRRR output");

        IMintable(brrr).mint(_account, mintAmount);

        lastAddedAt[_account] = block.timestamp;

        emit AddLiquidity(_account, _token, _amount, aumInUsdp, brrrSupply, usdpAmount, mintAmount);

        return mintAmount;
    }

    function _removeLiquidity(
        address _account,
        address _tokenOut,
        uint256 _brrrAmount,
        uint256 _minOut,
        address _receiver
    ) private returns (uint256) {
        require(_brrrAmount > 0, "BrrrManager: invalid _brrrAmount");
        require(
            lastAddedAt[_account] + cooldownDuration <= block.timestamp, "BrrrManager: cooldown duration not yet passed"
        );

        // calculate aum before sellUSDP
        uint256 aumInUsdp = getAumInUsdp(false);
        uint256 brrrSupply = IERC20(brrr).totalSupply();

        uint256 usdpAmount = (_brrrAmount * aumInUsdp) / brrrSupply;
        uint256 usdpBalance = IERC20(usdp).balanceOf(address(this));
        if (usdpAmount > usdpBalance) {
            IUSDP(usdp).mint(address(this), usdpAmount - usdpBalance);
        }

        IMintable(brrr).burn(_account, _brrrAmount);

        IERC20(usdp).transfer(address(vault), usdpAmount);
        uint256 amountOut = vault.sellUSDP(_tokenOut, _receiver);
        require(amountOut >= _minOut, "BrrrManager: insufficient output");

        emit RemoveLiquidity(_account, _tokenOut, _brrrAmount, aumInUsdp, brrrSupply, usdpAmount, amountOut);

        return amountOut;
    }

    function _validateHandler() private view {
        require(isHandler[msg.sender], "BrrrManager: forbidden");
    }
}
