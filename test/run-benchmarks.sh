#!/bin/bash

# Comprehensive Benchmark Test Runner
# This script runs all benchmark tests and provides a summary

echo "🚀 Starting Comprehensive AMM Benchmark Tests"
echo "=============================================="

# Set default deployment path if not provided
if [ -z "$DEPLOYMENT_PATH" ]; then
    export DEPLOYMENT_PATH="./deployments/testnet.json"
    echo "Using default deployment path: $DEPLOYMENT_PATH"
else
    echo "Using deployment path: $DEPLOYMENT_PATH"
fi

echo ""
echo "📊 Running Comprehensive Benchmark Tests..."
echo ""

# Run all benchmark tests
echo "1️⃣  Testing Swap Operations..."
forge test --match-test testSwapBenchmark -vv

echo ""
echo "2️⃣  Testing Add Liquidity Operations..."
forge test --match-test testAddLiquidityBenchmark -vv

echo ""
echo "3️⃣  Testing Remove Liquidity Operations..."
forge test --match-test testRemoveLiquidityBenchmark -vv

echo ""
echo "4️⃣  Testing Calculation Accuracy..."
forge test --match-test testCalculationAccuracy -vv

echo ""
echo "5️⃣  Generating Comprehensive Report..."
forge test --match-test testGenerateComprehensiveReport -vv

echo ""
echo "✅ All benchmark tests completed!"
echo ""
echo "📈 Summary of what was tested:"
echo "   • Gas efficiency comparison (BasicAMM vs BlendedAMM)"
echo "   • Swap operations with $ITERATIONS iterations"
echo "   • Add/Remove liquidity operations"
echo "   • LP token calculation accuracy"
echo "   • Impermanent loss calculation precision"
echo "   • Mathematical engine performance"
echo ""
echo "💡 Tips:"
echo "   • Set DEPLOYMENT_PATH env var to test different networks"
echo "   • Check console output for detailed gas comparisons"
echo "   • Run individual tests with: forge test --match-test <testName> -vv"
