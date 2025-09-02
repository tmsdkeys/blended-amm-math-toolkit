# Comprehensive AMM Benchmarking

This directory contains comprehensive benchmarking tests that compare the performance of `BasicAMM.sol` vs `BlendedAMM.sol` using actual deployed contracts.

## Overview

The `GasBenchmark.t.sol` test suite provides:

1. **Gas Efficiency Comparison** - Measures gas usage for all AMM operations
2. **Statistical Significance** - Multiple iterations for reliable averages
3. **Real Contract Testing** - Uses deployed contracts, not mocks

## Prerequisites

Before running benchmarks, ensure:

1. **Contracts are deployed** to your target network
2. **Bootstrap script has been run** to provide liquidity
3. **Deployment JSON file** exists (e.g., `./deployments/testnet.json`)

## Quickstart

Make sure to source your env variables (you'll need `$RPC_URL` and `$PRIVATE_KEY`):
```bash
source .env
```

Run all tests at once:
```bash
gblend test -vvv --rpc-url $RPC_URL
```

### Run Individual Tests

```bash
# Swap operations benchmark
gblend test --match-test testSwapBenchmark -vv

# Add liquidity benchmark
gblend test --match-test testAddLiquidityBenchmark -vv

# Remove liquidity benchmark
gblend test --match-test testRemoveLiquidityBenchmark -vv

# Generate comprehensive report
gblend test --match-test testGenerateComprehensiveReport -vv
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
- Compares different square root implementations in Rust.

### 3. Remove Liquidity Benchmark (`testRemoveLiquidityBenchmark`)
- Benchmarks liquidity removal operations
- Tests 25% LP token removal
- Compares gas efficiency of withdrawal logic
- Maintains consistent test conditions

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
gblend test --match-test testSwapBenchmark -vv
```

### Test Constants

```solidity
uint256 constant ITERATIONS = 4;                    // Test iterations
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
gblend test --match-test testSwapBenchmark -vvvv

# Run specific test with detailed logging
gblend test --match-test testCalculationAccuracy -vv
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
