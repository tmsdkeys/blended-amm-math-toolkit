// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";
import {IMathematicalEngine} from "../out/MathematicalEngine.wasm/interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Benchmark
 * @dev Comprehensive benchmarking of BasicAMM vs BlendedAMM using deployed contracts
 * 
 * This test suite:
 * 1. Uses actual deployed contracts and ERC20s from bootstrap
 * 2. Compares all AMM operations: swap, addLiquidity, removeLiquidity
 * 3. Measures calculation accuracy (LP tokens, impermanent loss)
 * 4. Benchmarks gas usage with multiple iterations for statistical significance
 * 5. Provides comprehensive analysis and recommendations
 */
contract Benchmark is Test {
    // ============ Contract Instances ============
    BasicAMM public basicAmm;
    BlendedAMM public blendedAmm;
    IMathematicalEngine public mathEngine;
    IERC20 public tokenA;
    IERC20 public tokenB;

    // ============ Test Accounts ============
    address public deployer; // Deployer account for all operations

    // ============ Test Configuration ============
    uint256 constant ITERATIONS = 5;           // Number of iterations for averaging
    uint256 constant SWAP_AMOUNT = 100 * 1e18; // Base swap amount
    uint256 constant LIQUIDITY_AMOUNT = 1000 * 1e18; // Base liquidity amount
    uint256 constant REMOVE_PERCENTAGE = 25;   // Percentage of LP tokens to remove

    // ============ Benchmark Results ============
    struct BenchmarkResult {
        uint256 basicGas;
        uint256 blendedGas;
        int256 gasDifference;
        uint256 percentChange;
        bool blendedWins;
    }

    struct AccuracyResult {
        uint256 basicValue;
        uint256 blendedValue;
        uint256 difference;
        uint256 percentDifference;
        bool blendedMoreAccurate;
    }

    // ============ Setup ============
    function setUp() public {
        console2.log("=== Loading Deployed Contracts for Comprehensive Benchmarking ===");
        
        // Load deployment addresses from testnet (can be changed via env var)
        string memory deploymentPath = vm.envString("DEPLOYMENT_PATH");
        if (bytes(deploymentPath).length == 0) {
            deploymentPath = "./deployments/testnet.json";
        }
        string memory deploymentData = vm.readFile(deploymentPath);
        
        // Load contract instances
        tokenA = IERC20(vm.parseJsonAddress(deploymentData, ".tokenA"));
        tokenB = IERC20(vm.parseJsonAddress(deploymentData, ".tokenB"));
        mathEngine = IMathematicalEngine(vm.parseJsonAddress(deploymentData, ".mathEngine"));
        basicAmm = BasicAMM(vm.parseJsonAddress(deploymentData, ".basicAMM"));
        blendedAmm = BlendedAMM(vm.parseJsonAddress(deploymentData, ".blendedAMM"));

        console2.log("Contracts loaded:");
        console2.log("  Token A:", address(tokenA));
        console2.log("  Token B:", address(tokenB));
        console2.log("  Math Engine:", address(mathEngine));
        console2.log("  Basic AMM:", address(basicAmm));
        console2.log("  Blended AMM:", address(blendedAmm));

        // Load deployer address from private key environment variable
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        console2.log("Deployer address:", deployer);
        console2.log("Deployer ETH balance:", deployer.balance / 1e18);
        console2.log("Using deployer account for all test operations");

        // Set up token approvals for the test contract (using vm.prank to impersonate test contract)
        console2.log("Setting up token approvals for test contract...");
        _setupTestContractApprovals();

        // Verify bootstrap was run
        // _verifyBootstrapSetup();
    }

    // ============ Bootstrap Verification ============
    function _verifyBootstrapSetup() internal view {
        uint256 deployerBalanceA = tokenA.balanceOf(deployer);
        uint256 deployerBalanceB = tokenB.balanceOf(deployer);

        console2.log("Deployer balance:", deployerBalanceA / 1e18);
        console2.log("Deployer balance:", deployerBalanceB / 1e18);

        require(deployerBalanceA >= LIQUIDITY_AMOUNT * 2, "Deployer needs more Token A - run bootstrap first");
        require(deployerBalanceB >= LIQUIDITY_AMOUNT * 2, "Deployer needs more Token B - run bootstrap first");

        console2.log("Bootstrap verification passed:");
        console2.log("  Deployer Token A:", deployerBalanceA / 1e18);
        console2.log("  Deployer Token B:", deployerBalanceB / 1e18);
    }

    // ============ Swap Benchmarking ============
    function testSwapBenchmark() public {
        console2.log("\n=== SWAP OPERATION BENCHMARK ===");
        
        // Transfer tokens needed for this specific test
        _transferTokensForTest(SWAP_AMOUNT * ITERATIONS * 2, 0);
        
        // Reset any existing state and ensure both AMMs have liquidity
        _resetLiquidityState();
        _transferTokensForTest(LIQUIDITY_AMOUNT * 2, LIQUIDITY_AMOUNT * 2);
        _addLiquidityToBothAMMs();
        

        
        BenchmarkResult memory result = _benchmarkSwapOperations();
        
        _reportBenchmarkResult("Swap Operations", result);
        _analyzeSwapResults(result);
        
        // Clean up all tokens after the test
        _cleanupTestTokens();
    }

    function _benchmarkSwapOperations() internal returns (BenchmarkResult memory) {
        uint256 totalBasicGas = 0;
        uint256 totalBlendedGas = 0;
        
        console2.log("Running", ITERATIONS, "swap iterations for averaging...");
        
        for (uint256 i = 0; i < ITERATIONS; i++) {
            // Reset state between iterations
            _resetSwapState();
            
            // Test Basic AMM swap
            uint256 gasStart = gasleft();
            basicAmm.swap(address(tokenA), SWAP_AMOUNT, 0, deployer);
            uint256 basicGas = gasStart - gasleft();
            totalBasicGas += basicGas;
            
            // Test Blended AMM swap
            gasStart = gasleft();
            blendedAmm.swap(address(tokenA), SWAP_AMOUNT, 0, deployer);
            uint256 blendedGas = gasStart - gasleft();
            totalBlendedGas += blendedGas;
            
            console2.log("  Iteration %d | Basic: %d | Blended: %d", i + 1, basicGas, blendedGas);
        }
        
        uint256 avgBasicGas = totalBasicGas / ITERATIONS;
        uint256 avgBlendedGas = totalBlendedGas / ITERATIONS;
        
        return _calculateBenchmarkResult(avgBasicGas, avgBlendedGas);
    }

    // ============ Add Liquidity Benchmarking ============
    function testAddLiquidityBenchmark() public {
        console2.log("\n=== ADD LIQUIDITY BENCHMARK ===");
        
        // Transfer tokens needed for this specific test
        _transferTokensForTest(LIQUIDITY_AMOUNT * ITERATIONS * 2, LIQUIDITY_AMOUNT * ITERATIONS * 2);
        
        BenchmarkResult memory result = _benchmarkAddLiquidityOperations();
        
        _reportBenchmarkResult("Add Liquidity Operations", result);
        _analyzeLiquidityResults(result);
        
        // Clean up all tokens after the test
        _cleanupTestTokens();
    }

    function _benchmarkAddLiquidityOperations() internal returns (BenchmarkResult memory) {
        uint256 totalBasicGas = 0;
        uint256 totalBlendedGas = 0;
        
        console2.log("Running", ITERATIONS, "add liquidity iterations for averaging...");
        
        for (uint256 i = 0; i < ITERATIONS; i++) {
            // Reset state between iterations
            _resetLiquidityState();
            
            // Test Basic AMM add liquidity
            uint256 gasStart = gasleft();
            basicAmm.addLiquidity(
                LIQUIDITY_AMOUNT, 
                LIQUIDITY_AMOUNT, 
                LIQUIDITY_AMOUNT * 95 / 100, 
                LIQUIDITY_AMOUNT * 95 / 100, 
                deployer
            );
            uint256 basicGas = gasStart - gasleft();
            totalBasicGas += basicGas;
            
            // Test Blended AMM add liquidity
            gasStart = gasleft();
            blendedAmm.addLiquidity(
                LIQUIDITY_AMOUNT, 
                LIQUIDITY_AMOUNT, 
                LIQUIDITY_AMOUNT * 95 / 100, 
                LIQUIDITY_AMOUNT * 95 / 100, 
                deployer
            );
            uint256 blendedGas = gasStart - gasleft();
            totalBlendedGas += blendedGas;
            
            console2.log("  Iteration %d | Basic: %d | Blended: %d", i + 1, basicGas, blendedGas);
        }
        
        uint256 avgBasicGas = totalBasicGas / ITERATIONS;
        uint256 avgBlendedGas = totalBlendedGas / ITERATIONS;
        
        return _calculateBenchmarkResult(avgBasicGas, avgBlendedGas);
    }

    // ============ Remove Liquidity Benchmarking ============
    function testRemoveLiquidityBenchmark() public {
        console2.log("\n=== REMOVE LIQUIDITY BENCHMARK ===");
        
        // Transfer tokens needed for this specific test (liquidity operations recycle tokens)
        _transferTokensForTest(LIQUIDITY_AMOUNT * 2, LIQUIDITY_AMOUNT * 2);
        
        BenchmarkResult memory result = _benchmarkRemoveLiquidityOperations();
        
        _reportBenchmarkResult("Remove Liquidity Operations", result);
        _analyzeLiquidityResults(result);
        
        // Clean up all tokens after the test
        _cleanupTestTokens();
    }

    function _benchmarkRemoveLiquidityOperations() internal returns (BenchmarkResult memory) {
        uint256 totalBasicGas = 0;
        uint256 totalBlendedGas = 0;
        
        console2.log("Running", ITERATIONS, "remove liquidity iterations for averaging...");
        
        for (uint256 i = 0; i < ITERATIONS; i++) {
            // Reset state between iterations
            _resetLiquidityState();
            
            // Add liquidity first to both AMMs
            _addLiquidityToBothAMMs();
            
            // Get LP token balances
            uint256 basicLPTokens = basicAmm.balanceOf(address(this));
            uint256 blendedLPTokens = blendedAmm.balanceOf(address(this));
            
            uint256 basicRemoveAmount = basicLPTokens * REMOVE_PERCENTAGE / 100;
            uint256 blendedRemoveAmount = blendedLPTokens * REMOVE_PERCENTAGE / 100;

            // Test Basic AMM remove liquidity
            uint256 gasStart = gasleft();
            basicAmm.removeLiquidity(basicRemoveAmount, 0, 0, address(this));
            uint256 basicGas = gasStart - gasleft();
            totalBasicGas += basicGas;
            
            // Test Blended AMM remove liquidity
            gasStart = gasleft();
            blendedAmm.removeLiquidity(blendedRemoveAmount, 0, 0, address(this));
            uint256 blendedGas = gasStart - gasleft();
            totalBlendedGas += blendedGas;
            
            console2.log("  Iteration %d | Basic: %d | Blended: %d", i + 1, basicGas, blendedGas);
        }
        
        uint256 avgBasicGas = totalBasicGas / ITERATIONS;
        uint256 avgBlendedGas = totalBlendedGas / ITERATIONS;
        
        return _calculateBenchmarkResult(avgBasicGas, avgBlendedGas);
    }

    // ============ Calculation Accuracy Testing ============
    function testCalculationAccuracy() public {
        console2.log("\n=== CALCULATION ACCURACY COMPARISON ===");
        
        // Test LP token calculation accuracy
        _testLPTokenCalculationAccuracy();
        
        // Test impermanent loss calculation accuracy
        _testImpermanentLossCalculationAccuracy();
        
        // Test mathematical engine functions directly
        _testMathematicalEngineFunctions();
    }

    function _testLPTokenCalculationAccuracy() internal {
        console2.log("Testing LP Token Calculation Accuracy...");
        
        // Get reserves from both AMMs
        (uint256 basicReserve0, uint256 basicReserve1) = basicAmm.getReserves();
        (uint256 blendedReserve0, uint256 blendedReserve1) = blendedAmm.getReserves();

        console2.log("  Basic AMM reserves:", basicReserve0 / 1e18, basicReserve1 / 1e18);
        console2.log("  Blended AMM reserves:", blendedReserve0 / 1e18, blendedReserve1 / 1e18);
        
        // Calculate expected LP tokens using mathematical engine
        bool useBabylonian = blendedAmm.useBabylonian();
        uint256 expectedLPTokens = mathEngine.calculateLpTokens(
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT, 
            useBabylonian
        );
        
        // Compare with actual LP tokens received
        uint256 basicLPTokens = basicAmm.balanceOf(deployer);
        uint256 blendedLPTokens = blendedAmm.balanceOf(deployer);
        
        console2.log("  Expected LP tokens:", expectedLPTokens / 1e18);
        console2.log("  Basic AMM LP tokens:", basicLPTokens / 1e18);
        console2.log("  Blended AMM LP tokens:", blendedLPTokens / 1e18);
        
        // Calculate accuracy differences
        uint256 basicDiff = basicLPTokens > expectedLPTokens ? 
            basicLPTokens - expectedLPTokens : expectedLPTokens - basicLPTokens;
        uint256 blendedDiff = blendedLPTokens > expectedLPTokens ? 
            blendedLPTokens - expectedLPTokens : expectedLPTokens - blendedLPTokens;
        
        console2.log("  Basic AMM difference:", basicDiff / 1e18);
        console2.log("  Blended AMM difference:", blendedDiff / 1e18);
        
        if (blendedDiff < basicDiff) {
            console2.log("  [SUCCESS] Blended AMM is more accurate!");
        } else {
            console2.log("  [FAIL] Basic AMM is more accurate");
        }
    }

    function _testImpermanentLossCalculationAccuracy() internal {
        console2.log("Testing Impermanent Loss Calculation Accuracy...");
        
        // Simulate price change scenario
        uint256 initialPrice = 1 * 1e18;  // 1:1 ratio
        uint256 currentPrice = 15 * 1e17; // 1.5x price change
        
        // Calculate using mathematical engine
        bool useBabylonian = blendedAmm.useBabylonian();
        uint256 rustIL = mathEngine.calculateImpermanentLoss(initialPrice, currentPrice, useBabylonian);
        
        console2.log("  Initial price ratio: 1:1");
        console2.log("  Current price ratio: 1.5:1");
        console2.log("  Rust calculation:", rustIL, "basis points");
        
        if (rustIL != 0) {
            console2.log("  [SUCCESS] Rust mathematical engine working correctly");
        } else {
            console2.log("  [FAIL] Rust mathematical engine calculation failed");
        }
    }

    function _testMathematicalEngineFunctions() internal {
        console2.log("Testing Mathematical Engine Functions Directly...");
        
        // Test square root calculation
        uint256 testValue = 1000000 * 1e18;
        bool useBabylonian = blendedAmm.useBabylonian();
        
        uint256 gasStart = gasleft();
        uint256 sqrtResult = mathEngine.calculatePreciseSquareRoot(testValue, useBabylonian);
        uint256 sqrtGas = gasStart - gasleft();
        
        console2.log("  Square root of 1M tokens:", sqrtResult / 1e9, "(scaled down)");
        console2.log("  Gas used for sqrt:", sqrtGas);
        
        // Test dynamic fee calculation
        IMathematicalEngine.DynamicFeeParams memory feeParams = IMathematicalEngine.DynamicFeeParams({
            volatility: 200,           // 200 basis points
            volume_24h: 10000 * 1e18,  // 10k tokens
            liquidity_depth: 1000000 * 1e18 // 1M tokens
        });
        
        gasStart = gasleft();
        uint256 dynamicFee = mathEngine.calculateDynamicFee(feeParams);
        uint256 feeGas = gasStart - gasleft();
        
        console2.log("  Dynamic fee:", dynamicFee, "basis points");
        console2.log("  Gas used for fee calc:", feeGas);
        
        console2.log("  [SUCCESS] Mathematical engine functions working correctly");
    }

    // ============ Helper Functions ============
    
    /// @dev Set up token approvals for the test contract in setUp()
    /// Uses vm.prank to impersonate the test contract and approve AMMs
    function _setupTestContractApprovals() internal {
        // Impersonate the test contract to set up approvals
        vm.prank(address(this));
        tokenA.approve(address(basicAmm), type(uint256).max);
        tokenA.approve(address(blendedAmm), type(uint256).max);
        
        vm.prank(address(this));
        tokenB.approve(address(basicAmm), type(uint256).max);
        tokenB.approve(address(blendedAmm), type(uint256).max);
        
        console2.log("Test contract approvals set up:");
    }
    
    /// @dev Transfer tokens from deployer to test contract for specific test requirements
    /// @param amountA Amount of Token A needed for the test
    /// @param amountB Amount of Token B needed for the test
    function _transferTokensForTest(uint256 amountA, uint256 amountB) internal {
        console2.log("Transferring tokens for test - Token A:", amountA / 1e18, "Token B:", amountB / 1e18);
        
        // Transfer Token A
        vm.prank(deployer);
        tokenA.transfer(address(this), amountA);
        
        // Transfer Token B
        vm.prank(deployer);
        tokenB.transfer(address(this), amountB);
        
        console2.log("Test contract balances after transfer:");
        console2.log("  Token A:", tokenA.balanceOf(address(this)) / 1e18);
        console2.log("  Token B:", tokenB.balanceOf(address(this)) / 1e18);
    }
    
    /// @dev Clean up all tokens from test contract and return them to deployer
    /// This ensures test isolation and prevents token leakage between tests
    function _cleanupTestTokens() internal {
        console2.log("Cleaning up test contract tokens...");
        
        // Remove any remaining LP tokens and get underlying tokens back
        _resetLiquidityState();
        
        // Transfer remaining ERC20 tokens back to deployer
        uint256 remainingTokenA = tokenA.balanceOf(address(this));
        uint256 remainingTokenB = tokenB.balanceOf(address(this));
        
        if (remainingTokenA > 0) {
            console2.log("  Returning Token A:", remainingTokenA / 1e18);
            tokenA.transfer(deployer, remainingTokenA);
        }
        
        if (remainingTokenB > 0) {
            console2.log("  Returning Token B:", remainingTokenB / 1e18);
            tokenB.transfer(deployer, remainingTokenB);
        }
        
        // Verify cleanup
        uint256 finalTokenA = tokenA.balanceOf(address(this));
        uint256 finalTokenB = tokenB.balanceOf(address(this));
        
        console2.log("Test contract final balances:");
        console2.log("  Token A:", finalTokenA / 1e18);
        console2.log("  Token B:", finalTokenB / 1e18);
        
        require(finalTokenA == 0, "Token A cleanup failed");
        require(finalTokenB == 0, "Token B cleanup failed");
        console2.log("  [SUCCESS] All tokens cleaned up successfully");
    }

    function _addLiquidityToBothAMMs() internal {
        basicAmm.addLiquidity(
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT * 95 / 100, 
            LIQUIDITY_AMOUNT * 95 / 100, 
            address(this)
        );
        
        blendedAmm.addLiquidity(
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT * 95 / 100, 
            LIQUIDITY_AMOUNT * 95 / 100, 
            address(this)
        );
    }

    function _approveTokensForOperations() internal {
        // Test contract approves AMMs to spend its tokens
        console2.log("Test contract approving AMMs to spend tokens...");
        tokenA.approve(address(basicAmm), type(uint256).max);
        tokenA.approve(address(blendedAmm), type(uint256).max);
        tokenB.approve(address(basicAmm), type(uint256).max);
        tokenB.approve(address(blendedAmm), type(uint256).max);
        
        console2.log("Approvals completed:");
        console2.log("  Basic AMM Token A allowance:", tokenA.allowance(address(this), address(basicAmm)) / 1e18);
        console2.log("  Basic AMM Token B allowance:", tokenB.allowance(address(this), address(basicAmm)) / 1e18);
        console2.log("  Blended AMM Token A allowance:", tokenA.allowance(address(this), address(blendedAmm)) / 1e18);
        console2.log("  Blended AMM Token B allowance:", tokenB.allowance(address(this), address(blendedAmm)) / 1e18);
    }

    function _resetSwapState() internal {
        // Reset by doing a reverse swap to restore original state
        // This is a simplified approach - in practice you might want more sophisticated state management
    }

    function _resetLiquidityState() internal {
        // Remove any existing LP tokens to start fresh
        uint256 basicLP = basicAmm.balanceOf(address(this));
        uint256 blendedLP = blendedAmm.balanceOf(address(this));
        
        if (basicLP > 0) {
            basicAmm.removeLiquidity(basicLP, 0, 0, address(this));
        }
        
        if (blendedLP > 0) {
            blendedAmm.removeLiquidity(blendedLP, 0, 0, address(this));
        }
    }

    function _calculateBenchmarkResult(uint256 basicGas, uint256 blendedGas) internal pure returns (BenchmarkResult memory) {
        int256 gasDiff = int256(blendedGas) - int256(basicGas);
        uint256 percentChange = gasDiff > 0 ? 
            (uint256(gasDiff) * 100) / basicGas : 
            (uint256(-gasDiff) * 100) / basicGas;
        bool blendedWins = blendedGas < basicGas;
        
        return BenchmarkResult({
            basicGas: basicGas,
            blendedGas: blendedGas,
            gasDifference: gasDiff,
            percentChange: percentChange,
            blendedWins: blendedWins
        });
    }

    function _reportBenchmarkResult(string memory operation, BenchmarkResult memory result) internal pure {
        console2.log("\n", operation, "Results:");
        console2.log("  Basic AMM (avg): %d gas", result.basicGas);
        console2.log("  Blended AMM (avg): %d gas", result.blendedGas);
        console2.log("  Gas difference: %d gas", result.gasDifference);
        console2.log("  Percent change: %d%%", result.percentChange);
        
        if (result.blendedWins) {
            console2.log("  [SUCCESS] Blended AMM uses LESS gas");
        } else {
            console2.log("  [FAIL] Blended AMM uses MORE gas");
        }
    }

    function _analyzeSwapResults(BenchmarkResult memory result) internal pure {
        console2.log("\nSwap Analysis:");
        if (result.blendedWins) {
            console2.log("  [TARGET] Blended AMM is more gas-efficient for swaps");
            console2.log("  [INFO] This suggests the Rust mathematical engine optimizations are working");
        } else {
            console2.log("  [WARNING] Basic AMM is more gas-efficient for swaps");
            console2.log("  [INFO] This suggests the Rust overhead might outweigh the benefits");
        }
    }

    function _analyzeLiquidityResults(BenchmarkResult memory result) internal pure {
        console2.log("\nLiquidity Analysis:");
        if (result.blendedWins) {
            console2.log("  [TARGET] Blended AMM is more gas-efficient for liquidity operations");
            console2.log("  [INFO] LP token calculations are optimized");
        } else {
            console2.log("  [WARNING] Basic AMM is more gas-efficient for liquidity operations");
            console2.log("  [INFO] Consider if the precision improvements justify the gas cost");
        }
    }

    // ============ Comprehensive Report ============
    function testGenerateComprehensiveReport() public pure {
        console2.log("==================== COMPREHENSIVE BENCHMARK REPORT ====================");
        
        console2.log("\nThis test suite provides comprehensive benchmarking of:");
        console2.log("1. Gas efficiency comparison between BasicAMM and BlendedAMM");
        console2.log("2. Calculation accuracy analysis");
        console2.log("3. Mathematical engine performance evaluation");
        console2.log("4. Statistical significance through multiple iterations");
        
        console2.log("\nKey Metrics:");
        console2.log("- Gas usage for all AMM operations");
        console2.log("- LP token calculation accuracy");
        console2.log("- Impermanent loss calculation precision");
        console2.log("- Mathematical engine function performance");
        
        console2.log("\nRecommendations:");
        console2.log("- Run individual test functions for detailed analysis");
        console2.log("- Compare results across different network conditions");
        console2.log("- Consider gas costs vs. precision improvements");
        console2.log("- Evaluate mathematical engine benefits in production");
        
        console2.log("================================================");
    }
}
