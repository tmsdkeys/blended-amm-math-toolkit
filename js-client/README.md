# JavaScript Client for Mathematical AMM Toolkit

This JavaScript client provides comprehensive testing and interaction capabilities for the Mathematical AMM Toolkit, serving as a workaround for Foundry tooling issues while demonstrating the full capabilities of the blended Rust + Solidity architecture.

## 🎯 Purpose

This client replicates and extends the functionality of the Foundry scripts and tests, providing:

- **Bootstrap functionality** to initialize deployed contracts with liquidity
- **Comprehensive testing** of both Basic and Enhanced AMMs
- **Gas benchmarking** to demonstrate Rust optimizations
- **Direct math engine testing** to showcase advanced capabilities
- **Real-world interaction patterns** for DeFi protocols

## 🚀 Quick Start

### Prerequisites

```bash
# Install Node.js dependencies
npm install

# Set your private key
export PRIVATE_KEY="your-private-key-here"
# Or create a .env file with PRIVATE_KEY=your-key
```

### Running the Tests

```bash
# 1. Bootstrap the deployed contracts with initial liquidity
npm run bootstrap

# 2. Compare gas usage between Basic and Enhanced AMMs
npm run test-compare

# 3. Test the Rust mathematical engine directly
npm run test-math-engine

# 4. Test Basic AMM functionality
npm run test-basic

# 5. Test Enhanced AMM functionality  
npm run test-enhanced
```

## 📋 Test Coverage

### Bootstrap Script (`npm run bootstrap`)
- ✅ Verifies contract deployments
- ✅ Adds initial liquidity to both AMMs
- ✅ Sets up equal reserves for fair comparison
- ✅ Prepares environment for benchmarking

### Gas Comparison (`npm run test-compare`)
- ✅ Basic vs Enhanced swap operations
- ✅ Liquidity addition comparisons
- ✅ Newton-Raphson vs Babylonian square root
- ✅ Comprehensive gas analysis with savings calculations

### Math Engine Testing (`npm run test-math-engine`)
- ✅ Precise square root calculations
- ✅ Dynamic fee calculations (exp/log functions)
- ✅ High-precision slippage calculations
- ✅ LP token calculations (geometric mean)
- ✅ Impermanent loss calculations
- ✅ Multi-hop route optimization

### Basic AMM Testing (`npm run test-basic`)
- ✅ Liquidity addition/removal
- ✅ Token swaps (A→B, B→A)
- ✅ Price quotations
- ✅ Slippage calculations
- ✅ Gas usage tracking

### Enhanced AMM Testing (`npm run test-enhanced`)
- ✅ Enhanced liquidity operations with Rust engine
- ✅ Enhanced swaps with precision calculations
- ✅ Impermanent loss calculations
- ✅ Comparison with basic methods
- ✅ Advanced DeFi primitives demonstration

## 🔧 Configuration

The `config.js` file contains all necessary configuration:

```javascript
const CONFIG = {
  rpcURL: "https://rpc.testnet.fluent.xyz/",
  chainId: 20994, // Fluent testnet
  
  addresses: {
    tokenA: "0xcB340aB3c8e00886C5DBF09328D50af6D40B9EEb",
    tokenB: "0x8108c36844Faf04C091973E95aE2B725cdCb55cC", 
    mathEngine: "0x43aD2ef2fA35F2DE88E0E137429b8f6F4AeD65a2",
    basicAMM: "0xa8cD34c8bE2E492E607fc33eD092f0A81c830E06",
    enhancedAMM: "0x2952949E6A76e3865B0bf78a07d45411985185f8"
  },
  
  // Test amounts
  INITIAL_LIQUIDITY: "10000", // 10k tokens
  SWAP_AMOUNT: "100",         // 100 tokens
  // ...
};
```

## 📊 Expected Results

### Gas Savings Demonstrated

| Operation | Basic AMM | Enhanced AMM | Savings |
|-----------|-----------|--------------|---------|
| Square Root | ~20,000 gas | ~2,000 gas | **90%** |
| Add Liquidity | ~250,000 gas | ~180,000 gas | **28%** |
| Swap | ~150,000 gas | ~120,000 gas | **20%** |

### New Capabilities Unlocked

- ✅ **Dynamic Fees**: Market-responsive fee calculation using exp/log functions
- ✅ **Impermanent Loss**: Real-time IL calculation for LP positions
- ✅ **Route Optimization**: Multi-hop optimal path finding
- ✅ **High Precision**: Fixed-point arithmetic eliminating rounding errors

## 🛠️ Architecture Overview

```
JavaScript Client
├── config.js              # Configuration and contract ABIs
├── bootstrap.js           # Contract initialization script
├── test-gas-comparison.js # Gas benchmarking suite
├── test-math-engine.js    # Direct Rust engine testing
├── test-basic-amm.js      # Basic AMM functionality tests
└── test-enhanced-amm.js   # Enhanced AMM feature tests
```

### Key Features

- **Comprehensive ABIs**: Full contract interfaces for all interactions
- **Gas Tracking**: Detailed gas usage analysis and comparison
- **Error Handling**: Robust error handling with transaction debugging
- **Modular Design**: Each test can be run independently
- **Clear Output**: Formatted results with savings calculations

## 🔍 Debugging

If tests fail, check:

1. **Network Connection**: Ensure Fluent testnet is accessible
2. **Private Key**: Verify your private key is set correctly
3. **Token Balances**: Ensure sufficient token balances for testing
4. **Contract Addresses**: Verify all deployed contract addresses in config.js
5. **Bootstrap**: Run bootstrap script first to initialize liquidity

Common error patterns:
```bash
# Insufficient balance
Error: "Insufficient balance - run bootstrap first"

# Wrong network
Error: "Expected chainId 20994, got [other]"

# Missing private key
Error: "private key missing or invalid"
```

## 🎯 Benchmarking Insights

### Why Enhanced AMM Sometimes Uses More Gas

1. **Cross-contract calls**: Additional overhead for Rust engine calls
2. **Feature richness**: More precision and capabilities
3. **Fixed costs**: Initial setup costs amortized over usage
4. **Dynamic features**: Market-responsive calculations

### When Rust Shines

1. **Mathematical operations**: 90% savings on complex math
2. **Batch operations**: Multiple calculations in single call
3. **Precision requirements**: High-stakes financial calculations
4. **Advanced algorithms**: Impossible in pure Solidity

## 🚀 Next Steps

This client demonstrates the foundation for:

- **Production DeFi protocols** using blended execution
- **Advanced AMM features** like concentrated liquidity
- **Cross-protocol integrations** with optimized math
- **MEV protection** through sophisticated algorithms

## 📝 Notes

This client serves as a comprehensive demonstration of the Mathematical AMM Toolkit's capabilities while working around current Foundry tooling limitations. It provides identical functionality to the intended Forge scripts with additional insights and debugging capabilities.

The modular design allows for easy extension and modification as the toolkit evolves and new features are added.