// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BasicAMM
 * @dev Baseline constant product AMM implementation (x * y = k)
 * This contract demonstrates standard Solidity mathematical operations
 * that are candidates to be optimized with Rust.
 */
contract BasicAMM is ERC20, ReentrancyGuard, Ownable {
    // ============ State Variables ============

    IERC20 public immutable TOKEN0;
    IERC20 public immutable TOKEN1;

    uint256 public reserve0;
    uint256 public reserve1;

    uint256 public constant MINIMUM_LIQUIDITY = 1000;
    uint256 public feeRate = 997; // 0.3% fee (997/1000) - now configurable

    // Gas tracking for benchmarking
    uint256 public lastSwapGasUsed;
    uint256 public lastLiquidityGasUsed;
    uint256 public lastRemoveLiquidityGasUsed;

    // ============ Events ============

    event Swap(
        address indexed user, address indexed tokenIn, address indexed tokenOut, uint256 amountIn, uint256 amountOut
    );

    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);

    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidity);

    event GasUsageRecorded(string operation, uint256 gasUsed);

    // Admin events
    event FeeRateUpdated(uint256 newFeeRate);

    // ============ Constructor ============

    constructor(address _token0, address _token1, string memory _name, string memory _symbol)
        ERC20(_name, _symbol)
        Ownable(msg.sender)
    {
        require(_token0 != _token1, "Identical tokens");
        require(_token0 != address(0) && _token1 != address(0), "Zero address");

        TOKEN0 = IERC20(_token0);
        TOKEN1 = IERC20(_token1);
    }

    // ============ Admin Functions ============

    /**
     * @dev Set the fee rate for swaps
     * @param _feeRate New fee rate (e.g., 997 = 0.3% fee, 995 = 0.5% fee)
     */
    function setFeeRate(uint256 _feeRate) external onlyOwner {
        require(_feeRate >= 900 && _feeRate <= 999, "Invalid fee rate"); // Between 10% and 0.1%
        feeRate = _feeRate;
        emit FeeRateUpdated(_feeRate);
    }

    // ============ Core AMM Functions ============

    /**
     * @dev Add liquidity to the pool
     * Uses standard Solidity square root approximation for LP tokens
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

        // Calculate liquidity tokens to mint
        if (totalSupply() == 0) {
            // First liquidity provider
            liquidity = _sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(this), MINIMUM_LIQUIDITY); // Lock minimum liquidity
        } else {
            // Subsequent liquidity providers
            liquidity = _min((amount0 * totalSupply()) / reserve0, (amount1 * totalSupply()) / reserve1);
        }

        require(liquidity > 0, "Insufficient liquidity minted");
        _mint(to, liquidity);

        // Update reserves
        reserve0 += amount0;
        reserve1 += amount1;

        lastLiquidityGasUsed = gasStart - gasleft();
        emit GasUsageRecorded("addLiquidity", lastLiquidityGasUsed);
        emit LiquidityAdded(to, amount0, amount1, liquidity);
    }

    /**
     * @dev Remove liquidity from the pool
     */
    function removeLiquidity(uint256 liquidity, uint256 amount0Min, uint256 amount1Min, address to)
        external
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 gasStart = gasleft();

        require(liquidity > 0, "Insufficient liquidity");

        // Calculate amounts to return
        uint256 _totalSupply = totalSupply();
        amount0 = (liquidity * reserve0) / _totalSupply;
        amount1 = (liquidity * reserve1) / _totalSupply;

        require(amount0 >= amount0Min, "Insufficient amount0");
        require(amount1 >= amount1Min, "Insufficient amount1");

        // Burn liquidity tokens
        _burn(msg.sender, liquidity);

        // Transfer tokens back
        require(TOKEN0.transfer(to, amount0), "TOKEN0 transfer failed");
        require(TOKEN1.transfer(to, amount1), "TOKEN1 transfer failed");

        // Update reserves
        reserve0 -= amount0;
        reserve1 -= amount1;

        // Record gas usage
        lastRemoveLiquidityGasUsed = gasStart - gasleft();
        emit GasUsageRecorded("removeLiquidity", lastRemoveLiquidityGasUsed);
        emit LiquidityRemoved(to, amount0, amount1, liquidity);
    }

    /**
     * @dev Execute a swap (token0 -> token1 or token1 -> token0)
     * Uses standard Solidity arithmetic with precision limitations
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

        // Calculate output amount using constant product formula
        // amountOut = (amountIn * fee * reserveOut) / (reserveIn * 1000 + amountIn * fee)
        (uint256 reserveIn, uint256 reserveOut) = isToken0 ? (reserve0, reserve1) : (reserve1, reserve0);

        amountOut = _getAmountOut(amountIn, reserveIn, reserveOut);
        require(amountOut >= amountOutMin, "Insufficient output amount");

        // Transfer tokens
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

        lastSwapGasUsed = gasStart - gasleft();
        emit GasUsageRecorded("swap", lastSwapGasUsed);
        emit Swap(msg.sender, tokenIn, isToken0 ? address(TOKEN1) : address(TOKEN0), amountIn, amountOut);
    }

    // ============ View Functions ============

    /**
     * @dev Calculate impermanent loss using pure Solidity
     * @param initialPrice The initial price ratio (price1/price0) when liquidity was added
     * @param currentPrice The current price ratio (price1/price0)
     * @return impermanentLoss The impermanent loss in basis points (1 = 0.01%)
     *
     * Impermanent Loss Formula: IL = (2 * √(price_ratio)) / (1 + price_ratio) - 1
     * Where price_ratio = current_price / initial_price
     *
     * Returns value in basis points (1 = 0.01%, 100 = 1%, 10000 = 100%)
     * This matches the Rust engine implementation
     */
    function calculateImpermanentLoss(uint256 initialPrice, uint256 currentPrice) external pure returns (uint256) {
        return _calculateImpermanentLossBps(initialPrice, currentPrice);
    }

    function getReserves() external view returns (uint256, uint256) {
        return (reserve0, reserve1);
    }

    function getGasMetrics()
        external
        view
        returns (uint256 swapGas, uint256 addLiquidityGas, uint256 removeLiquidityGas)
    {
        return (lastSwapGasUsed, lastLiquidityGasUsed, lastRemoveLiquidityGasUsed);
    }

    function quote(uint256 amountA, uint256 reserveA, uint256 reserveB) external pure returns (uint256 amountB) {
        require(amountA > 0, "Insufficient amount");
        require(reserveA > 0 && reserveB > 0, "Insufficient liquidity");
        amountB = (amountA * reserveB) / reserveA;
    }

    // ============ Mathematical Helper Functions ============
    // These are the functions that are candidates to be optimized with Rust

    /**
     * @dev Calculate square root using Babylonian method
     */
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        // Babylonian method iteration (expensive!)
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    /**
     * @dev Calculate output amount for a given input (constant product formula)
     * Limited precision due to Solidity integer arithmetic
     */
    function _getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal view returns (uint256) {
        require(amountIn > 0, "Insufficient input amount");
        require(reserveIn > 0 && reserveOut > 0, "Insufficient liquidity");

        uint256 amountInWithFee = amountIn * feeRate;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;

        return numerator / denominator; // Integer division = precision loss
    }

    /**
     * @dev Calculate precise slippage (simplified version)
     * This is a candidate for optimization with Rust
     */
    function calculateSlippage(uint256 amountIn, uint256 reserveIn, uint256 reserveOut)
        external
        pure
        returns (uint256 slippagePercent)
    {
        uint256 amountOut = (amountIn * reserveOut) / (reserveIn + amountIn);
        uint256 idealRate = (reserveOut * 1000) / reserveIn; // Price before trade
        uint256 actualRate = (amountOut * 1000) / amountIn; // Actual execution price

        if (idealRate > actualRate) {
            slippagePercent = ((idealRate - actualRate) * 100) / idealRate;
        }

        return slippagePercent; // Returns percentage * 100 (e.g., 150 = 1.5%)
    }

    /**
     * @dev Calculate impermanent loss in basis points (internal helper)
     * @param initialPrice The initial price ratio (price1/price0) when liquidity was added
     * @param currentPrice The current price ratio (price1/price0)
     * @return impermanentLossBps The impermanent loss in basis points (1 = 0.01%)
     *
     * Impermanent Loss Formula: IL = (2 * √(price_ratio)) / (1 + price_ratio) - 1
     * Where price_ratio = current_price / initial_price
     *
     * Returns value in basis points (1 = 0.01%, 100 = 1%, 10000 = 100%)
     * This matches the Rust engine implementation
     */
    function _calculateImpermanentLossBps(uint256 initialPrice, uint256 currentPrice) internal pure returns (uint256) {
        require(initialPrice > 0, "Initial price must be positive");
        require(currentPrice > 0, "Current price must be positive");

        // Calculate price ratio: current_price / initial_price
        uint256 priceRatio = (currentPrice * 1e18) / initialPrice;

        // Calculate square root of price ratio using Babylonian method
        uint256 sqrtPriceRatio = _sqrt(priceRatio);

        // Calculate numerator: 2 * √(price_ratio)
        uint256 numerator = 2 * sqrtPriceRatio;

        // Calculate denominator: 1 + price_ratio
        uint256 denominator = 1e18 + priceRatio;

        // Calculate the ratio: (2 * √(price_ratio)) / (1 + price_ratio)
        uint256 ratio = (numerator * 1e18) / denominator;

        // Calculate impermanent loss: ratio - 1
        // This gives us the loss as a percentage of the initial value
        if (ratio > 1e18) {
            // Gain scenario
            return 0;
        } else {
            // Loss scenario - convert to basis points
            uint256 loss = 1e18 - ratio;
            return (loss * 10000) / 1e18;
        }
    }

    // ============ Internal Helper Functions ============

    function _calculateOptimalAmounts(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min
    ) internal view returns (uint256 amount0, uint256 amount1) {
        if (reserve0 == 0 && reserve1 == 0) {
            // First liquidity addition
            return (amount0Desired, amount1Desired);
        }

        // Calculate optimal amounts maintaining current ratio
        uint256 amount1Optimal = (amount0Desired * reserve1) / reserve0;
        if (amount1Optimal <= amount1Desired) {
            require(amount1Optimal >= amount1Min, "Insufficient amount1");
            return (amount0Desired, amount1Optimal);
        } else {
            uint256 amount0Optimal = (amount1Desired * reserve0) / reserve1;
            require(amount0Optimal >= amount0Min, "Insufficient amount0");
            return (amount0Optimal, amount1Desired);
        }
    }

    function _min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }
}
