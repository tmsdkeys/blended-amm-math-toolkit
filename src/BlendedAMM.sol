// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// Import the auto-generated interface from gblend
import {IMathematicalEngine} from "../out/MathematicalEngine.wasm/interface.sol";

/**
 * @title BlendedAMM
 * @dev Blended execution constant product (x * y = k) AMM
 * that leverages Rust mathematical engine for high-precision calculations
 * and advanced features.
 */
contract BlendedAMM is ERC20, ReentrancyGuard, Ownable {
    // ============ State Variables ============

    IERC20 public immutable TOKEN0;
    IERC20 public immutable TOKEN1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public baseFeeRate = 30; // 0.3% in basis points

    // Rust mathematical engine integration
    IMathematicalEngine public immutable MATH_ENGINE;

    // Enhanced features state
    bool public useBabylonian = true;
    bool public dynamicFeesEnabled = true;
    uint256 public volume24h;
    uint256 public lastVolumeUpdate;
    uint256 public priceVolatility = 100; // Start at 100 basis points

    // Gas tracking for benchmarking
    uint256 public lastSwapGasUsed;
    uint256 public lastLiquidityGasUsed;
    uint256 public lastRemoveLiquidityGasUsed;

    // ============ Events ============

    event Swap(address indexed user, address indexed tokenIn, uint256 amountIn, uint256 amountOut, uint256 dynamicFee);

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);

    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);

    event DynamicFeeUpdated(uint256 newFee);

    event UseBabylonianUpdated(bool newUseBabylonian);
    event BaseFeeRateUpdated(uint256 newBaseFeeRate);
    event DynamicFeesEnabledUpdated(bool newDynamicFeesEnabled);
    event PriceVolatilityUpdated(uint256 newPriceVolatility);

    // Gas tracking event
    event GasUsageRecorded(string operation, uint256 gasUsed);

    // ============ Constructor ============

    constructor(address _token0, address _token1, address _mathEngine, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        require(_token0 != _token1, "Identical tokens");
        require(_token0 != address(0) && _token1 != address(0), "Zero address");
        require(_mathEngine != address(0), "Invalid math engine");

        TOKEN0 = IERC20(_token0);
        TOKEN1 = IERC20(_token1);
        MATH_ENGINE = IMathematicalEngine(_mathEngine);
        lastVolumeUpdate = block.timestamp;
    }

    // ============ Admin Functions ============

    /**
     * @dev Set whether to use Babylonian method for calculations
     * @param _useBabylonian New value for useBabylonian
     */
    function setUseBabylonian(bool _useBabylonian) external onlyOwner {
        useBabylonian = _useBabylonian;
        emit UseBabylonianUpdated(_useBabylonian);
    }

    /**
     * @dev Set the base fee rate for swaps
     * @param _baseFeeRate New fee rate in basis points (e.g., 30 = 0.3%)
     */
    function setBaseFeeRate(uint256 _baseFeeRate) external onlyOwner {
        require(_baseFeeRate <= 1000, "Fee rate too high"); // Max 10%
        baseFeeRate = _baseFeeRate;
        emit BaseFeeRateUpdated(_baseFeeRate);
    }

    /**
     * @dev Enable or disable dynamic fees
     * @param _enabled New state for dynamic fees
     */
    function setDynamicFeesEnabled(bool _enabled) external onlyOwner {
        dynamicFeesEnabled = _enabled;
        emit DynamicFeesEnabledUpdated(_enabled);
    }

    /**
     * @dev Set the price volatility parameter for dynamic fee calculations
     * @param _priceVolatility New volatility value in basis points
     */
    function setPriceVolatility(uint256 _priceVolatility) external onlyOwner {
        require(_priceVolatility <= 10000, "Volatility too high"); // Max 100%
        priceVolatility = _priceVolatility;
        emit PriceVolatilityUpdated(_priceVolatility);
    }

    // ============ Liquidity Functions ============

    /**
     * @dev Add liquidity using Rust-powered calculations
     */
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external nonReentrant returns (uint256 liquidity) {
        uint256 gasStart = gasleft();
        (uint256 amount0, uint256 amount1) =
            _calculateOptimalAmounts(amount0Desired, amount1Desired, amount0Min, amount1Min);

        // Transfer tokens
        require(TOKEN0.transferFrom(msg.sender, address(this), amount0), "TOKEN0 transfer failed");
        require(TOKEN1.transferFrom(msg.sender, address(this), amount1), "TOKEN1 transfer failed");

        // Use Rust engine for precise LP token calculation
        if (totalSupply() == 0) {
            // First liquidity provider - use geometric mean via Rust
            liquidity = MATH_ENGINE.calculateLpTokens(amount0, amount1, useBabylonian);

            // Ensure minimum liquidity
            require(liquidity > MINIMUM_LIQUIDITY, "Insufficient initial liquidity");
            liquidity = liquidity - MINIMUM_LIQUIDITY;
            _mint(address(this), MINIMUM_LIQUIDITY); // Lock minimum liquidity
        } else {
            // Calculate proportional liquidity
            uint256 liquidity0 = (amount0 * totalSupply()) / reserve0;
            uint256 liquidity1 = (amount1 * totalSupply()) / reserve1;
            liquidity = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        _mint(to, liquidity);

        // Update reserves
        reserve0 += amount0;
        reserve1 += amount1;

        // Record gas usage
        lastLiquidityGasUsed = gasStart - gasleft();
        emit GasUsageRecorded("addLiquidity", lastLiquidityGasUsed);

        emit LiquidityAdded(to, amount0, amount1, liquidity);
    }

    /**
     * @dev Remove liquidity
     */
    function removeLiquidity(uint256 liquidity, uint256 amount0Min, uint256 amount1Min, address to)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 gasStart = gasleft();
        require(liquidity > 0, "Insufficient liquidity");

        uint256 _totalSupply = totalSupply();

        // Calculate amounts proportionally
        amount0 = (liquidity * reserve0) / _totalSupply;
        amount1 = (liquidity * reserve1) / _totalSupply;

        require(amount0 >= amount0Min, "Insufficient amount0");
        require(amount1 >= amount1Min, "Insufficient amount1");

        // Burn LP tokens
        _burn(msg.sender, liquidity);

        // Update reserves
        reserve0 -= amount0;
        reserve1 -= amount1;

        // Transfer tokens
        require(TOKEN0.transfer(to, amount0), "TOKEN0 transfer failed");
        require(TOKEN1.transfer(to, amount1), "TOKEN1 transfer failed");

        // Record gas usage
        lastRemoveLiquidityGasUsed = gasStart - gasleft();
        emit GasUsageRecorded("removeLiquidity", lastRemoveLiquidityGasUsed);

        emit LiquidityRemoved(to, amount0, amount1, liquidity);
    }

    // ============ Swap Functions ============

    /**
     * @dev Swap using Rust engine for potential optimization
     */
    function swap(address tokenIn, uint256 amountIn, uint256 amountOutMin, address to)
        external
        nonReentrant
        returns (uint256 amountOut)
    {
        uint256 gasStart = gasleft();
        require(amountIn > 0, "Insufficient input amount");
        require(tokenIn == address(TOKEN0) || tokenIn == address(TOKEN1), "Invalid token");

        bool isToken0 = tokenIn == address(TOKEN0);
        (uint256 reserveIn, uint256 reserveOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        // Get dynamic fee if enabled
        uint256 feeRate = dynamicFeesEnabled ? _getDynamicFee() : baseFeeRate;

        // For swap optimization, we could use the Rust engine's optimizeSwapAmount
        // but for simplicity, we'll use the precise slippage calculation
        IMathematicalEngine.SlippageParams memory slippageParams =
            IMathematicalEngine.SlippageParams(amountIn, reserveIn, reserveOut, feeRate);

        // Calculate output using Rust engine
        amountOut = MATH_ENGINE.calculatePreciseSlippage(slippageParams);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // Execute swap
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Token transfer failed");

        if (isToken0) {
            require(TOKEN1.transfer(to, amountOut), "TOKEN1 transfer failed");
            reserve0 += amountIn;
            reserve1 -= amountOut;
        } else {
            require(TOKEN0.transfer(to, amountOut), "TOKEN0 transfer failed");
            reserve1 += amountIn;
            reserve0 -= amountOut;
        }

        // Update volume tracking
        _updateVolume(amountIn);

        // Record gas usage
        lastSwapGasUsed = gasStart - gasleft();
        emit GasUsageRecorded("swap", lastSwapGasUsed);

        emit Swap(msg.sender, tokenIn, amountIn, amountOut, feeRate);
    }

    // ============ View Functions ============

    /**
     * @dev Get current reserves
     */
    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    /**
     * @dev Get gas usage metrics for benchmarking
     */
    function getGasMetrics()
        external
        view
        returns (uint256 swapGas, uint256 addLiquidityGas, uint256 removeLiquidityGas)
    {
        return (lastSwapGasUsed, lastLiquidityGasUsed, lastRemoveLiquidityGasUsed);
    }

    /**
     * @dev Calculate impermanent loss using Rust engine
     * @return impermanentLoss The impermanent loss in basis points (1 = 0.01%)
     */
    function calculateImpermanentLoss(uint256 initialPrice, uint256 currentPrice) external returns (uint256) {
        return MATH_ENGINE.calculateImpermanentLoss(initialPrice, currentPrice, useBabylonian);
    }

    /**
     * @dev Preview swap output
     */
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256) {
        bool isToken0 = tokenIn == address(TOKEN0);
        (uint256 reserveIn, uint256 reserveOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        uint256 amountInWithFee = amountIn * (10000 - baseFeeRate);
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = reserveIn * 10000 + amountInWithFee;
        return numerator / denominator;
    }

    // ============ Helper Functions ============

    /**
     * @dev Get dynamic fee from Rust engine
     */
    function _getDynamicFee() internal returns (uint256) {
        IMathematicalEngine.DynamicFeeParams memory params =
            IMathematicalEngine.DynamicFeeParams(priceVolatility, volume24h, reserve0 + reserve1);

        uint256 dynamicFee = MATH_ENGINE.calculateDynamicFee(params);
        emit DynamicFeeUpdated(dynamicFee);
        return dynamicFee;
    }

    /**
     * @dev Calculate optimal amounts for liquidity provision
     */
    function _calculateOptimalAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            (amount0, amount1) = (amount0Desired, amount1Desired);
        } else {
            uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
            if (amount1Optimal <= amount1Desired) {
                require(amount1Optimal >= amount1Min, "Insufficient amount1");
                (amount0, amount1) = (amount0Desired, amount1Optimal);
            } else {
                uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
                assert(amount0Optimal <= amount0Desired);
                require(amount0Optimal >= amount0Min, "Insufficient amount0");
                (amount0, amount1) = (amount0Optimal, amount1Desired);
            }
        }
    }

    /**
     * @dev Update 24h volume tracking
     */
    function _updateVolume(uint256 amount) internal {
        // Reset volume every 24 hours
        if (block.timestamp > lastVolumeUpdate + 24 hours) {
            volume24h = amount;
            lastVolumeUpdate = block.timestamp;
        } else {
            volume24h += amount;
        }
    }
}
