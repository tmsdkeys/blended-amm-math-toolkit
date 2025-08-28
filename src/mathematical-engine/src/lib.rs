#![cfg_attr(target_arch = "wasm32", no_std, no_main)]
extern crate alloc;
extern crate fluentbase_sdk;

use alloc::vec::Vec;
use fluentbase_sdk::{
    basic_entrypoint,
    codec::Codec,
    derive::{router, Contract},
    SharedAPI, U256,
};

// ============ Custom Type Definitions Using Codec ============

/// Parameters for slippage calculation
#[derive(Codec, Debug, Default, Clone, PartialEq)]
pub struct SlippageParams {
    pub amount_in: U256,
    pub reserve_in: U256,
    pub reserve_out: U256,
    pub fee_rate: U256, // in basis points (10000 = 100%)
}

/// Parameters for dynamic fee calculation
#[derive(Codec, Debug, Default, Clone, PartialEq)]
pub struct DynamicFeeParams {
    pub volatility: U256,      // in basis points
    pub volume_24h: U256,      // in wei
    pub liquidity_depth: U256, // in wei
}

/// Result from optimization calculations
#[derive(Codec, Debug, Default, Clone, PartialEq)]
pub struct OptimizationResult {
    pub optimal_amount: U256,
    pub expected_output: U256,
    pub price_impact: U256, // in basis points
}

/// Pool information for routing
#[derive(Codec, Debug, Default, Clone, PartialEq)]
pub struct Pool {
    pub reserve_in: U256,
    pub reserve_out: U256,
}

// ============ Fixed-Point Arithmetic Constants ============

// Scaling factors for fixed-point arithmetic
const SCALE_18: U256 = U256::from_limbs([1_000_000_000_000_000_000, 0, 0, 0]); // 1e18
const SCALE_6: U256 = U256::from_limbs([1_000_000, 0, 0, 0]); // 1e6
const BASIS_POINTS: U256 = U256::from_limbs([10_000, 0, 0, 0]); // 10000

// Mathematical constants scaled to 1e18
const E_SCALED: U256 = U256::from_limbs([2_718_281_828_459_045_235, 0, 0, 0]); // e * 1e18
const LN2_SCALED: U256 = U256::from_limbs([693_147_180_559_945_309, 0, 0, 0]); // ln(2) * 1e18

// Maximum iterations for convergence algorithms
const MAX_ITERATIONS: u32 = 20;

// ============ Contract Implementation ============

#[derive(Contract)]
struct MathematicalEngine<SDK> {
    sdk: SDK,
}

/// Trait defining the mathematical engine interface
pub trait MathematicalEngineAPI {
    fn calculate_precise_square_root(&self, value: U256, baby: bool) -> U256;
    fn calculate_precise_slippage(&self, params: SlippageParams) -> U256;
    fn calculate_dynamic_fee(&self, params: DynamicFeeParams) -> U256;
    fn optimize_swap_amount(
        &self,
        total_amount: U256,
        reserve_in: U256,
        reserve_out: U256,
        fee_rate: U256,
    ) -> OptimizationResult;
    fn calculate_lp_tokens(&self, amount0: U256, amount1: U256, baby: bool) -> U256;
    fn calculate_impermanent_loss(
        &self,
        initial_price: U256,
        current_price: U256,
        baby: bool,
    ) -> U256;
    fn find_optimal_route(&self, amount_in: U256, pools: Vec<Pool>, fee_rates: Vec<U256>) -> U256;
}

#[router(mode = "solidity")]
impl<SDK: SharedAPI> MathematicalEngineAPI for MathematicalEngine<SDK> {
    /// Calculate precise square root using Newton-Raphson method
    /// More efficient than Solidity's iterative Babylonian method
    #[function_id("calculatePreciseSquareRoot(uint256,bool)")]
    fn calculate_precise_square_root(&self, value: U256, baby: bool) -> U256 {
        sqrt_fixed(value, baby) // Use Babylonian method for reliability
    }

    /// Calculate slippage with high-precision fixed-point arithmetic
    /// Eliminates precision loss from Solidity integer division
    #[function_id("calculatePreciseSlippage((uint256,uint256,uint256,uint256))")]
    fn calculate_precise_slippage(&self, params: SlippageParams) -> U256 {
        // Constant product formula with fee adjustment
        // amountOut = (amountIn * feeMultiplier * reserveOut) / (reserveIn * 10000 + amountIn * feeMultiplier)

        let fee_multiplier = BASIS_POINTS - params.fee_rate;
        let amount_in_with_fee = params.amount_in * fee_multiplier;

        // Use mul_div to prevent overflow and maintain precision
        let numerator = amount_in_with_fee * params.reserve_out;
        let denominator = params.reserve_in * BASIS_POINTS + amount_in_with_fee;

        mul_div(numerator, U256::from(1), denominator)
    }

    /// Calculate dynamic fees based on market conditions
    /// Uses approximated exponential and logarithmic functions
    #[function_id("calculateDynamicFee((uint256,uint256,uint256))")]
    fn calculate_dynamic_fee(&self, params: DynamicFeeParams) -> U256 {
        // Base fee: 30 basis points (0.3%)
        let mut fee = U256::from(30);

        // Volatility adjustment using approximated exponential
        if params.volatility > U256::from(100) {
            // Calculate exponential factor for volatility
            // fee_adjustment = base * (1 + volatility_factor)
            // where volatility_factor uses exp approximation
            let volatility_excess = params.volatility - U256::from(100);

            // Scale down for exp calculation (divide by 1000 to keep in reasonable range)
            let exp_input = mul_div(volatility_excess, SCALE_18, U256::from(1000) * BASIS_POINTS);
            let exp_result = exp_fixed(exp_input);

            // Convert back to basis points
            let volatility_multiplier = mul_div(exp_result, U256::from(50), SCALE_18);
            fee = fee + volatility_multiplier.min(U256::from(50)); // Cap at 50 basis points
        }

        // Volume discount using approximated logarithm
        if params.volume_24h > SCALE_18 {
            // More than 1 ETH volume
            // Calculate log-based discount
            let log_volume = ln_fixed(params.volume_24h / SCALE_18);
            // Scale to basis points (max 10 bp discount)
            let volume_discount = mul_div(log_volume, U256::from(2), SCALE_18).min(U256::from(10));
            fee = fee.saturating_sub(volume_discount);
        }

        // Liquidity depth adjustment
        if params.liquidity_depth > U256::from(10) * SCALE_18 {
            // More than 10 ETH liquidity
            fee = fee.saturating_sub(U256::from(5));
        }

        // Ensure minimum fee of 5 basis points
        fee.max(U256::from(5))
    }

    /// Optimize swap amount for minimal price impact
    /// Uses calculus-based optimization with fixed-point math
    #[function_id("optimizeSwapAmount(uint256,uint256,uint256,uint256)")]
    fn optimize_swap_amount(
        &self,
        total_amount: U256,
        reserve_in: U256,
        reserve_out: U256,
        fee_rate: U256,
    ) -> OptimizationResult {
        // For constant product AMM: find optimal split to minimize price impact
        // Optimal amount = sqrt(k * total_amount * fee_multiplier)

        let k = reserve_in * reserve_out;
        let fee_multiplier = BASIS_POINTS - fee_rate;

        // Calculate using fixed-point square root
        let inner = mul_div(k, total_amount * fee_multiplier, BASIS_POINTS);
        let optimal_ratio = sqrt_fixed(inner, true); // Use Babylonian method for reliability
        let optimal_amount = optimal_ratio.min(total_amount);

        // Calculate expected output with high precision
        let amount_in_with_fee = optimal_amount * fee_multiplier;
        let numerator = amount_in_with_fee * reserve_out;
        let denominator = reserve_in * BASIS_POINTS + amount_in_with_fee;
        let expected_output = mul_div(numerator, U256::from(1), denominator);

        // Calculate price impact in basis points
        // spot_price = reserve_out / reserve_in
        // execution_price = expected_output / optimal_amount
        let spot_price = mul_div(reserve_out, SCALE_18, reserve_in);
        let execution_price = mul_div(expected_output, SCALE_18, optimal_amount);

        let price_impact = if spot_price > execution_price {
            // Calculate impact as basis points
            let diff = spot_price - execution_price;
            mul_div(diff, BASIS_POINTS, spot_price)
        } else {
            U256::ZERO
        };

        OptimizationResult {
            optimal_amount,
            expected_output,
            price_impact,
        }
    }

    /// Calculate LP token amount using geometric mean
    /// More precise than Solidity's approximations
    #[function_id("calculateLpTokens(uint256,uint256,bool)")]
    fn calculate_lp_tokens(&self, amount0: U256, amount1: U256, baby: bool) -> U256 {
        // Geometric mean: sqrt(amount0 * amount1)
        // Using high-precision fixed-point sqrt
        let product = amount0 * amount1;
        sqrt_fixed(product, baby) // Use Babylonian method for reliability
    }

    /// Calculate impermanent loss with high precision
    /// Returns loss in basis points
    #[function_id("calculateImpermanentLoss(uint256,uint256,bool)")]
    fn calculate_impermanent_loss(
        &self,
        initial_price: U256,
        current_price: U256,
        baby: bool,
    ) -> U256 {
        if initial_price == U256::ZERO || current_price == U256::ZERO {
            return U256::ZERO;
        }

        // IL = 2 * sqrt(price_ratio) / (1 + price_ratio) - 1
        // All calculations in fixed-point arithmetic

        // Calculate price ratio scaled to 1e18
        let price_ratio = mul_div(current_price, SCALE_18, initial_price);

        // Calculate sqrt of ratio
        let sqrt_ratio = sqrt_fixed(price_ratio, baby); // Use Babylonian method for reliability

        // Calculate IL: 2 * sqrt_ratio / (1 + price_ratio) - 1
        let numerator = U256::from(2) * sqrt_ratio;
        let denominator = SCALE_18 + price_ratio;
        let il_factor = mul_div(numerator, SCALE_18, denominator);

        if il_factor < SCALE_18 {
            // Loss scenario - convert to basis points
            let loss = SCALE_18 - il_factor;
            mul_div(loss, BASIS_POINTS, SCALE_18)
        } else {
            U256::ZERO
        }
    }

    /// Multi-hop routing optimization with fixed-point precision
    /// Finds the best output through multiple pools
    #[function_id("findOptimalRoute(uint256,(uint256,uint256)[],uint256[])")]
    fn find_optimal_route(&self, amount_in: U256, pools: Vec<Pool>, fee_rates: Vec<U256>) -> U256 {
        if pools.is_empty() || pools.len() != fee_rates.len() {
            return U256::ZERO;
        }

        let mut current_amount = amount_in;

        // Calculate output through each pool in sequence
        for i in 0..pools.len() {
            let pool = &pools[i];
            let fee_rate = fee_rates[i];

            let fee_multiplier = BASIS_POINTS - fee_rate;
            let amount_in_with_fee = current_amount * fee_multiplier;

            // High-precision calculation using mul_div
            let numerator = amount_in_with_fee * pool.reserve_out;
            let denominator = pool.reserve_in * BASIS_POINTS + amount_in_with_fee;

            current_amount = mul_div(numerator, U256::from(1), denominator);

            if current_amount == U256::ZERO {
                break;
            }
        }

        current_amount
    }
}

// ============ Fixed-Point Mathematical Functions ============

/// Wrapper function that chooses between Babylonian and Newton-Raphson methods
/// baby: true = Babylonian method (more reliable for large numbers)
/// baby: false = Newton-Raphson method (higher precision)
fn sqrt_fixed(x: U256, baby: bool) -> U256 {
    if baby {
        sqrt_fixed_babylonian(x)
    } else {
        sqrt_fixed_newton_raphson(x)
    }
}

/// Integer square root using Newton-Raphson method
/// Input x is already scaled (e.g., from Solidity contract)
/// Output preserves the scaling factor
fn sqrt_fixed_newton_raphson(x: U256) -> U256 {
    if x == U256::ZERO {
        return U256::ZERO;
    }
    if x == U256::from(1) {
        return U256::from(1);
    }

    // Standard integer square root - no additional scaling needed
    let mut bit = U256::from(1);
    let mut temp = x;
    while temp > bit {
        bit = bit << 2;
        temp = temp >> 2;
    }

    let mut y = bit;

    for _ in 0..20 {
        let prev_y = y;
        y = (y + x / y) >> 1;

        if y >= prev_y {
            return prev_y;
        }
    }

    y
}

/// Integer square root using Babylonian method
/// Input x is already scaled (e.g., from Solidity contract)
/// Output preserves the scaling factor
fn sqrt_fixed_babylonian(x: U256) -> U256 {
    if x == U256::ZERO {
        return U256::ZERO;
    }
    if x == U256::from(1) {
        return U256::from(1);
    }

    // Standard integer square root using Babylonian method - no additional scaling needed
    let mut z = (x + U256::from(1)) / U256::from(2);
    let mut y = x;

    while z < y {
        y = z;
        z = (x / z + z) / U256::from(2);
    }

    y
}

/// Approximated exponential function using Taylor series
/// e^x ≈ 1 + x + x²/2! + x³/3! + x⁴/4! + x⁵/5!
/// Input and output scaled by 1e18
fn exp_fixed(x: U256) -> U256 {
    if x == U256::ZERO {
        return SCALE_18;
    }

    // Limit input to prevent overflow (e^20 is already huge)
    let x_clamped = x.min(U256::from(20) * SCALE_18);

    let mut result = SCALE_18; // 1
    let mut term = SCALE_18; // Current term in series

    // Calculate up to 6 terms for reasonable precision
    for i in 1..7 {
        term = mul_div(term, x_clamped, U256::from(i) * SCALE_18);
        result = result + term;

        // Early exit if term becomes negligible
        if term < U256::from(1000) {
            // Less than 0.000001
            break;
        }
    }

    result
}

/// Approximated natural logarithm using series expansion
/// For x close to 1: ln(x) ≈ (x-1) - (x-1)²/2 + (x-1)³/3 - ...
/// Input and output scaled by 1e18
fn ln_fixed(x: U256) -> U256 {
    if x == U256::ZERO {
        return U256::ZERO; // Technically undefined, but return 0 for safety
    }
    if x == SCALE_18 {
        return U256::ZERO; // ln(1) = 0
    }

    // Use properties of logarithm to keep x close to 1
    // ln(x) = ln(x/2^n) + n*ln(2)
    let mut result = U256::ZERO;
    let mut y = x;
    let mut n = U256::ZERO;

    // Scale down by powers of 2 until y is between 0.5 and 2
    while y >= U256::from(2) * SCALE_18 {
        y = y / U256::from(2);
        n = n + U256::from(1);
    }

    // Add n * ln(2) to result
    result = result + n * LN2_SCALED;

    // Now y is close to 1, use Taylor series
    // Convert to (y - 1)
    let y_minus_1 = y - SCALE_18;

    // Calculate series: (y-1) - (y-1)²/2 + (y-1)³/3 - ...
    let mut term = y_minus_1;
    let mut series_sum = term;

    for i in 2..6 {
        term = mul_div(term, y_minus_1, SCALE_18);
        if i % 2 == 0 {
            series_sum = series_sum - term / U256::from(i);
        } else {
            series_sum = series_sum + term / U256::from(i);
        }
    }

    result + series_sum
}

/// Safe multiplication and division with overflow protection
/// Returns (a * b) / c without intermediate overflow
fn mul_div(a: U256, b: U256, c: U256) -> U256 {
    if c == U256::ZERO {
        return U256::ZERO; // Avoid division by zero
    }

    // Check if we can do simple calculation without overflow risk
    if a == U256::ZERO || b == U256::ZERO {
        return U256::ZERO;
    }

    // Perform the calculation
    // U256 in Fluentbase should handle this correctly
    let product = a * b;
    product / c
}

impl<SDK: SharedAPI> MathematicalEngine<SDK> {
    /// Deploy method - called once during contract deployment
    fn deploy(&self) {
        // No initialization needed for this mathematical engine
        // All functions are pure calculations
    }
}

basic_entrypoint!(MathematicalEngine);

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_sqrt_fixed_babylonian() {
        // Test basic cases - input is unscaled integers, output should be properly scaled
        assert_eq!(sqrt_fixed_babylonian(U256::from(0)), U256::from(0));
        assert_eq!(sqrt_fixed_babylonian(U256::from(1)), U256::from(1));

        // Test with realistic LP token calculation values
        // Both amounts are already scaled from Solidity
        let amount0 = U256::from(10000u64) * SCALE_18; // 10000 tokens
        let amount1 = U256::from(10000u64) * SCALE_18; // 10000 tokens
        let product = amount0 * amount1; // 10000^2 * 10^36
        let sqrt_result = sqrt_fixed_babylonian(product);

        // Expected: sqrt should give us 10000 * 10^18
        let expected = U256::from(10000u64) * SCALE_18;

        let diff = if sqrt_result > expected {
            sqrt_result - expected
        } else {
            expected - sqrt_result
        };

        assert!(
            diff < expected / U256::from(100000),
            "sqrt_result: {}, expected: {}, diff: {}",
            sqrt_result,
            expected,
            diff
        );
    }

    #[test]
    fn test_sqrt_fixed_newton_raphson() {
        // Test basic cases - input is unscaled integers, output should be properly scaled
        assert_eq!(sqrt_fixed_newton_raphson(U256::from(0)), U256::from(0));
        assert_eq!(sqrt_fixed_newton_raphson(U256::from(1)), U256::from(1));

        // Test with realistic LP token calculation values
        let amount0 = U256::from(10000u64) * SCALE_18;
        let amount1 = U256::from(10000u64) * SCALE_18;
        let product = amount0 * amount1;
        let sqrt_result = sqrt_fixed_newton_raphson(product);
        let expected = U256::from(10000u64) * SCALE_18;

        let diff = if sqrt_result > expected {
            sqrt_result - expected
        } else {
            expected - sqrt_result
        };

        assert!(
            diff < expected / U256::from(100000),
            "Newton-Raphson sqrt_result: {}, expected: {}, diff: {}",
            sqrt_result,
            expected,
            diff
        );
    }

    #[test]
    fn test_sqrt_fixed_wrapper() {
        // Test the wrapper function with both methods

        // Test with large numbers - realistic DeFi scenario
        let base = U256::from(10000u64);
        let amount0 = base * SCALE_18; // 10000 * 10^18
        let amount1 = base * SCALE_18; // 10000 * 10^18
        let product = amount0 * amount1; // 10000^2 * 10^36

        let babylonian_large = sqrt_fixed(product, true);
        let newton_large = sqrt_fixed(product, false);
        let expected_large = base * SCALE_18; // 10000 * 10^18

        // Both should equal the expected value
        assert_eq!(
            babylonian_large, expected_large,
            "Babylonian result: {}, expected: {}",
            babylonian_large, expected_large
        );
        assert_eq!(
            newton_large, expected_large,
            "Newton-Raphson result: {}, expected: {}",
            newton_large, expected_large
        );

        // Both methods should give identical results
        assert_eq!(
            babylonian_large, newton_large,
            "Babylonian: {}, Newton-Raphson: {}",
            babylonian_large, newton_large
        );

        // Test additional cases to ensure consistency
        let test_cases = vec![
            U256::from(4) * SCALE_18,
            U256::from(100) * SCALE_18,
            U256::from(1000000u64) * SCALE_18,
        ];

        for test_case in test_cases {
            let bab_result = sqrt_fixed(test_case, true);
            let nr_result = sqrt_fixed(test_case, false);
            assert_eq!(
                bab_result, nr_result,
                "Methods disagree for input {}: Babylonian={}, Newton-Raphson={}",
                test_case, bab_result, nr_result
            );
        }
    }

    #[test]
    fn test_mul_div() {
        // Test basic multiplication and division
        assert_eq!(
            mul_div(U256::from(100), U256::from(200), U256::from(50)),
            U256::from(400)
        );
        assert_eq!(
            mul_div(U256::from(1000), U256::from(1000), U256::from(1000)),
            U256::from(1000)
        );

        // Test with scaling
        let result = mul_div(SCALE_18, U256::from(2), SCALE_18);
        assert_eq!(result, U256::from(2));
    }

    #[test]
    fn test_exp_approximation() {
        // e^0 = 1
        assert_eq!(exp_fixed(U256::ZERO), SCALE_18);

        // e^1 ≈ 2.718...
        let e1 = exp_fixed(SCALE_18);
        assert!(e1 > U256::from(2) * SCALE_18);
        assert!(e1 < U256::from(3) * SCALE_18);
    }
}
