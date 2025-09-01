// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IAmm
 * @dev Common interface for AMM implementations
 * Defines the standard functions that all AMM contracts should implement
 */
interface IAmm {
    // ============ State Variables ============
    
    function TOKEN0() external view returns (IERC20);
    function TOKEN1() external view returns (IERC20);
    function reserve0() external view returns (uint256);
    function reserve1() external view returns (uint256);
    function MINIMUM_LIQUIDITY() external view returns (uint256);

    // ============ Core AMM Functions ============

    /**
     * @dev Add liquidity to the pool
     * @param amount0Desired Desired amount of token0
     * @param amount1Desired Desired amount of token1
     * @param amount0Min Minimum amount of token0 to add
     * @param amount1Min Minimum amount of token1 to add
     * @param to Address to receive the liquidity tokens
     * @return liquidity Amount of liquidity tokens minted
     */
    function addLiquidity(
        uint256 amount0Desired,
        uint256 amount1Desired,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external returns (uint256 liquidity);

    /**
     * @dev Remove liquidity from the pool
     * @param liquidity Amount of liquidity tokens to burn
     * @param amount0Min Minimum amount of token0 to receive
     * @param amount1Min Minimum amount of token1 to receive
     * @param to Address to receive the tokens
     * @return amount0 Amount of token0 received
     * @return amount1 Amount of token1 received
     */
    function removeLiquidity(
        uint256 liquidity,
        uint256 amount0Min,
        uint256 amount1Min,
        address to
    ) external returns (uint256 amount0, uint256 amount1);

    /**
     * @dev Execute a swap
     * @param tokenIn Address of the input token
     * @param amountIn Amount of input tokens
     * @param amountOutMin Minimum amount of output tokens expected
     * @param to Address to receive the output tokens
     * @return amountOut Amount of output tokens received
     */
    function swap(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external returns (uint256 amountOut);

    // ============ View Functions ============

    /**
     * @dev Get current reserves
     * @return reserve0 Current reserve of token0
     * @return reserve1 Current reserve of token1
     */
    function getReserves() external view returns (uint256 reserve0, uint256 reserve1);

    /**
     * @dev Get gas usage metrics for benchmarking
     * @return swapGas Gas used for last swap operation
     * @return addLiquidityGas Gas used for last add liquidity operation
     * @return removeLiquidityGas Gas used for last remove liquidity operation
     */
    function getGasMetrics()
        external
        view
        returns (uint256 swapGas, uint256 addLiquidityGas, uint256 removeLiquidityGas);

    /**
     * @dev Calculate impermanent loss
     * @param initialPrice The initial price ratio when liquidity was added
     * @param currentPrice The current price ratio
     * @return impermanentLoss The impermanent loss in basis points (1 = 0.01%)
     */
    function calculateImpermanentLoss(uint256 initialPrice, uint256 currentPrice) external returns (uint256 impermanentLoss);

    // ============ Events ============

    event Swap(
        address indexed user,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    event LiquidityAdded(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event LiquidityRemoved(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidity
    );

    event GasUsageRecorded(string operation, uint256 gasUsed);
}
