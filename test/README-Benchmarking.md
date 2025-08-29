# Comprehensive AMM Benchmarking

This directory contains comprehensive benchmarking tests that compare the performance of `BasicAMM.sol` vs `BlendedAMM.sol` using actual deployed contracts.

## Overview

The `ComprehensiveBenchmark.t.sol` test suite provides:

1. **Gas Efficiency Comparison** - Measures gas usage for all AMM operations
2. **Calculation Accuracy Analysis** - Compares LP token and impermanent loss calculations
3. **Mathematical Engine Performance** - Evaluates Rust WASM engine benefits
4. **Statistical Significance** - Multiple iterations for reliable averages
5. **Real Contract Testing** - Uses deployed contracts, not mocks

## Prerequisites

Before running benchmarks, ensure:

1. **Contracts are deployed** to your target network
2. **Bootstrap script has been run** to provide liquidity and test accounts
3. **Deployment JSON file** exists (e.g., `./deployments/testnet.json`)

## Quick Start

### Run All Benchmarks

```bash
# Using default testnet deployment
./test/run-benchmarks.sh

# Or specify custom deployment path
DEPLOYMENT_PATH="./deployments/devnet.json" ./test/run-benchmarks.sh
```

### Run Individual Tests

```bash
# Swap operations benchmark
forge test --match-test testSwapBenchmark -vv

# Add liquidity benchmark
forge test --match-test testAddLiquidityBenchmark -vv

# Remove liquidity benchmark
forge test --match-test testRemoveLiquidityBenchmark -vv

# Calculation accuracy test
forge test --match-test testCalculationAccuracy -vv

# Generate comprehensive report
forge test --match-test testGenerateComprehensiveReport -vv
```

## Test Structure

### 1. Swap Operations Benchmark (`testSwapBenchmark`)
- Compares gas usage for token swaps
- Runs 5 iterations for statistical significance
- Ensures both AMMs have sufficient liquidity
- Reports gas savings/increase percentages

### 2. Add Liquidity Benchmark (`testAddLiquidityBenchmark`)
- Measures gas usage for adding liquidity
- Tests optimal amount calculations
- Compares LP token minting efficiency
- Resets state between iterations

### 3. Remove Liquidity Benchmark (`testRemoveLiquidityBenchmark`)
- Benchmarks liquidity removal operations
- Tests 25% LP token removal
- Compares gas efficiency of withdrawal logic
- Maintains consistent test conditions

### 4. Calculation Accuracy Test (`testCalculationAccuracy`)
- **LP Token Accuracy**: Compares actual vs expected LP tokens
- **Impermanent Loss**: Tests precision of IL calculations
- **Mathematical Engine**: Direct function performance testing
- **Solidity vs Rust**: Accuracy comparison

### 5. Comprehensive Report (`testGenerateComprehensiveReport`)
- Overview of all benchmark capabilities
- Key metrics and recommendations
- Usage guidelines and best practices

## Configuration

### Environment Variables

```bash
# Set deployment file path (defaults to testnet.json)
export DEPLOYMENT_PATH="./deployments/devnet.json"

# Run tests with custom deployment
forge test --match-test testSwapBenchmark -vv
```

### Test Constants

```solidity
uint256 constant ITERATIONS = 5;                    // Test iterations
uint256 constant SWAP_AMOUNT = 100 * 1e18;         // Base swap amount
uint256 constant LIQUIDITY_AMOUNT = 1000 * 1e18;   // Base liquidity amount
uint256 constant REMOVE_PERCENTAGE = 25;            // LP removal percentage
```

## Understanding Results

### Gas Comparison Results

```
Swap Operations Results:
  Basic AMM (avg): 125,000 gas
  Blended AMM (avg): 118,000 gas
  Gas difference: -7,000 gas
  Percent change: 5.6%
  [SUCCESS] Blended AMM uses LESS gas
```

### Accuracy Analysis

```
Testing LP Token Calculation Accuracy...
  Expected LP tokens: 1000.0
  Basic AMM LP tokens: 999.8
  Blended AMM LP tokens: 1000.0
  Basic AMM difference: 0.2
  Blended AMM difference: 0.0
  [SUCCESS] Blended AMM is more accurate!
```

## Key Metrics

### Gas Efficiency
- **Swap Operations**: Token exchange gas usage
- **Liquidity Operations**: Add/remove liquidity gas costs
- **Mathematical Functions**: Direct engine performance

### Accuracy Improvements
- **LP Token Calculations**: Precision of liquidity token minting
- **Impermanent Loss**: Accuracy of IL calculations
- **Price Impact**: Slippage calculation precision

### Performance Analysis
- **Gas Savings**: Percentage reduction in gas usage
- **Accuracy Gains**: Improvement in calculation precision
- **Trade-offs**: Gas cost vs. precision benefits

## Best Practices

### Running Benchmarks
1. **Ensure Clean State**: Run bootstrap script before benchmarking
2. **Multiple Iterations**: Use default 5 iterations for reliable averages
3. **Network Conditions**: Test on target network for accurate gas costs
4. **Token Balances**: Verify sufficient test account balances

### Interpreting Results
1. **Gas Efficiency**: Lower gas usage is generally better
2. **Accuracy**: Higher precision may justify gas costs
3. **Consistency**: Look for consistent results across iterations
4. **Context**: Consider network conditions and token economics

### Customization
1. **Adjust Iterations**: Modify `ITERATIONS` constant for more/fewer tests
2. **Change Amounts**: Adjust `SWAP_AMOUNT` and `LIQUIDITY_AMOUNT`
3. **Network Selection**: Use different deployment files for various networks
4. **Test Focus**: Run individual tests for specific analysis

## Troubleshooting

### Common Issues

**"Insufficient balance - run bootstrap first"**
- Ensure bootstrap script has been executed
- Check token balances in deployment file
- Verify test account funding

**"Failed to load deployment file"**
- Check `DEPLOYMENT_PATH` environment variable
- Verify deployment JSON file exists
- Ensure correct file path format

**"Mathematical engine calculation failed"**
- Verify WASM contract deployment
- Check math engine address in deployment file
- Ensure Rust compilation was successful

### Debug Mode

```bash
# Run with maximum verbosity
forge test --match-test testSwapBenchmark -vvvv

# Run specific test with detailed logging
forge test --match-test testCalculationAccuracy -vv
```

## Advanced Usage

### Custom Benchmark Scenarios

```solidity
// Modify test constants for different scenarios
uint256 constant LARGE_SWAP_AMOUNT = 10000 * 1e18;
uint256 constant SMALL_LIQUIDITY = 100 * 1e18;

// Add custom test functions
function testCustomScenario() public {
    // Your custom benchmark logic
}
```

### Integration with CI/CD

```yaml
# Example GitHub Actions workflow
- name: Run AMM Benchmarks
  run: |
    export DEPLOYMENT_PATH="./deployments/mainnet.json"
    ./test/run-benchmarks.sh
```

## Contributing

When adding new benchmark tests:

1. **Follow Naming Convention**: Use `test*` prefix for test functions
2. **Include Documentation**: Add clear comments explaining test purpose
3. **Maintain Consistency**: Use existing helper functions and structures
4. **Add Analysis**: Include result interpretation and recommendations

## Support

For issues or questions about benchmarking:

1. Check this README for common solutions
2. Review test output for error details
3. Verify deployment and bootstrap setup
4. Check contract compilation and deployment status
