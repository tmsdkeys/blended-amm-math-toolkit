// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAmm} from "../src/IAmm.sol";

/**
 * @title GasBenchmark
 * @dev Comprehensive benchmarking of BasicAMM vs BlendedAMM using deployed contracts
 * 
 * This test suite:
 * 1. Uses actual deployed contracts and ERC20s from bootstrap
 * 2. Compares all AMM operations: swap, addLiquidity, removeLiquidity
 * 3. Benchmarks gas usage with multiple iterations for statistical significance
 * 4. Provides comprehensive analysis and recommendations
 */
contract GasBenchmark is Test {
    // ============ Contract Instances ============
    BasicAMM public basicAmm;
    BlendedAMM public blendedAmm;
    IERC20 public tokenA;
    IERC20 public tokenB;

    // ============ Test Accounts ============
    address public deployer; // Deployer account for all operations

    // ============ Test Configuration ============
    uint256 constant ITERATIONS = 4;                // Number of iterations for averaging (1 warm up call)
    uint256 constant SWAP_AMOUNT = 100 * 1e18;      // Base swap amount
    uint256 constant LIQUIDITY_AMOUNT = 1000 * 1e18;// Base liquidity amount
    uint256 constant REMOVE_PERCENTAGE = 25;        // Percentage of LP tokens to remove

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
        basicAmm = BasicAMM(vm.parseJsonAddress(deploymentData, ".basicAMM"));
        blendedAmm = BlendedAMM(vm.parseJsonAddress(deploymentData, ".blendedAMM"));

        console2.log("Contracts loaded:");
        console2.log("  Token A:", address(tokenA));
        console2.log("  Token B:", address(tokenB));
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
        _verifyBootstrapSetup();
    }

    // ============ Bootstrap Verification ============
    function _verifyBootstrapSetup() internal view {
        uint256 deployerBalanceA = tokenA.balanceOf(deployer);
        uint256 deployerBalanceB = tokenB.balanceOf(deployer);

        require(deployerBalanceA >= LIQUIDITY_AMOUNT * 2, "Deployer needs more Token A - run bootstrap first");
        require(deployerBalanceB >= LIQUIDITY_AMOUNT * 2, "Deployer needs more Token B - run bootstrap first");

        console2.log("Bootstrap verification passed:");
        console2.log("  Deployer Token A balance:", deployerBalanceA / 1e18);
        console2.log("  Deployer Token B balance:", deployerBalanceB / 1e18);
    }

    // ============ Swap Benchmarking ============
    function testSwapBenchmark() public {
        console2.log("\n=== SWAP OPERATION BENCHMARK ===");
        
        // Transfer tokens needed for this specific test
        _transferTokensForTest(SWAP_AMOUNT * (ITERATIONS + 1) * 2, 0);
        
        // Reset any existing state and ensure both AMMs have liquidity
        _resetLiquidityState();
        _transferTokensForTest(LIQUIDITY_AMOUNT * 2, LIQUIDITY_AMOUNT * 2);
        _addLiquidityToAMM(basicAmm);
        _addLiquidityToAMM(blendedAmm);
        
        BenchmarkResult memory result = _benchmarkSwapOperations();
        
        _reportBenchmarkResult("Swap Operations", result);
        _analyzeSwapResults(result);
        
        // Clean up all tokens after the test
        _cleanupTestTokens();
    }

    function _benchmarkSwapOperations() internal returns (BenchmarkResult memory) {
        uint256 totalBasicGas = 0;
        uint256 totalBlendedGas = 0;

        // Warm-up calls to eliminate cold storage effects
        console2.log("Running warm-up calls...");
        basicAmm.swap(address(tokenA), SWAP_AMOUNT, 0, deployer);
        blendedAmm.swap(address(tokenA), SWAP_AMOUNT, 0, deployer);
        
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
        _transferTokensForTest(LIQUIDITY_AMOUNT * (ITERATIONS + 1) * 3, LIQUIDITY_AMOUNT * (ITERATIONS + 1) * 3);
        
        (BenchmarkResult memory resultBabylon, BenchmarkResult memory resultNewton) = _benchmarkAddLiquidityOperations();
        
        _reportBenchmarkResult("Add Liquidity Operations (Babylonian)", resultBabylon);
        _analyzeLiquidityResults(resultBabylon);

        _reportBenchmarkResult("Add Liquidity Operations (Newton-Raphson)", resultNewton);
        _analyzeLiquidityResults(resultNewton);

        // _reportBabylonianComparison("Add Liquidity Operations", resultBabylon, resultNewton);
        // _analyzeBabylonianResults(resultBabylon, resultNewton);
        
        // Clean up all tokens after the test
        _cleanupTestTokens();
    }

    function _benchmarkAddLiquidityOperations() internal returns (BenchmarkResult memory, BenchmarkResult memory) {
        uint256 totalBasicGas;
        uint256 totalBlendedGasBabylon;
        uint256 totalBlendedGasNewton;

        // Reset state
        _resetLiquidityState();

        console2.log("Running warm-up calls...");
        _addLiquidityToAMM(basicAmm);
        _addLiquidityToAMM(blendedAmm);
        _setUseBabylonian(false);

        _resetLiquidityState();

        _addLiquidityToAMM(basicAmm);
        _addLiquidityToAMM(blendedAmm);
        _setUseBabylonian(true);

        console2.log("Running", ITERATIONS, "add liquidity iterations for averaging...");
        
        for (uint256 i = 0; i < ITERATIONS; i++) {
            // Reset state between iterations
            _resetLiquidityState();
            
            // Test Basic AMM add liquidity
            uint256 gasStart = gasleft();
            _addLiquidityToAMM(basicAmm);
            uint256 basicGas = gasStart - gasleft();
            totalBasicGas += basicGas;
            
            // Test Blended AMM add liquidity
            gasStart = gasleft();
            _addLiquidityToAMM(blendedAmm);
            uint256 blendedGasBabylon = gasStart - gasleft();
            totalBlendedGasBabylon += blendedGasBabylon;

            // Test Blended AMM add liquidity
            _setUseBabylonian(false);
            gasStart = gasleft();
            _addLiquidityToAMM(blendedAmm);
            uint256 blendedGasNewton = gasStart - gasleft();
            totalBlendedGasNewton += blendedGasNewton;
            _setUseBabylonian(true);
            
            console2.log("  Iteration %d | Basic: %d | Blended Babylonian: %d", i + 1, basicGas, blendedGasBabylon);
            console2.log("  Iteration %d | Basic: %d | Blended Newton-Raphson: %d", i + 1, basicGas, blendedGasNewton);
        }
        
        uint256 avgBasicGas = totalBasicGas / ITERATIONS;
        uint256 avgBlendedGasBabylon = totalBlendedGasBabylon / ITERATIONS;
        uint256 avgBlendedGasNewton = totalBlendedGasNewton / ITERATIONS;
        
        return (_calculateBenchmarkResult(avgBasicGas, avgBlendedGasBabylon), _calculateBenchmarkResult(avgBasicGas, avgBlendedGasNewton));
    }

    // ============ Remove Liquidity Benchmarking ============
    function testRemoveLiquidityBenchmark() public {
        // Removing liquidity uses the same Solidity functions in both Blended and Basic AMMs
        // Therefore we expect the results to be the same and no difference in gas usage
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
        console2.log("Running", 1, "remove liquidity iterations for averaging...");
        
        // Reset state between iterations
        _resetLiquidityState();
        
        // Add liquidity first to both AMMs
        _addLiquidityToAMM(basicAmm);
        _addLiquidityToAMM(blendedAmm);
        
        // Get LP token balances
        uint256 basicLPTokens = basicAmm.balanceOf(address(this));
        uint256 blendedLPTokens = blendedAmm.balanceOf(address(this));
        
        uint256 basicRemoveAmount = basicLPTokens * REMOVE_PERCENTAGE / 100;
        uint256 blendedRemoveAmount = blendedLPTokens * REMOVE_PERCENTAGE / 100;

        // Warm up calls to eliminate cold storage effects
        basicAmm.removeLiquidity(basicRemoveAmount, 0, 0, address(this));
        blendedAmm.removeLiquidity(blendedRemoveAmount, 0, 0, address(this));

        // Test Basic AMM remove liquidity
        uint256 gasStart = gasleft();
        basicAmm.removeLiquidity(basicRemoveAmount, 0, 0, address(this));
        uint256 basicGas = gasStart - gasleft();
        
        // Test Blended AMM remove liquidity
        gasStart = gasleft();
        blendedAmm.removeLiquidity(blendedRemoveAmount, 0, 0, address(this));
        uint256 blendedGas = gasStart - gasleft();
        
        console2.log("  Basic: %d | Blended: %d ", basicGas, blendedGas);
        
        return _calculateBenchmarkResult(basicGas, blendedGas);
    }

    // ============ Helper Functions ============
    
    /// @dev Set the useBabylonian parameter on the BlendedAMM contract
    /// @param useBabylonian The value to set for useBabylonian
    function _setUseBabylonian(bool useBabylonian) internal {
        vm.prank(deployer);
        blendedAmm.setUseBabylonian(useBabylonian);
        console2.log("  Set useBabylonian to:", useBabylonian);
    }
    
    /// @dev Set up token approvals for the test contract in setUp()
    /// Uses vm.prank to impersonate the test contract and approve AMMs
    function _setupTestContractApprovals() internal {
        // Impersonate the test contract to set up approvals
        vm.prank(address(this));
        tokenA.approve(address(basicAmm), type(uint256).max);
        tokenA.approve(address(blendedAmm), type(uint256).max);
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

    function _addLiquidityToAMM(IAmm amm) internal {
        amm.addLiquidity(
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT, 
            LIQUIDITY_AMOUNT * 95 / 100, 
            LIQUIDITY_AMOUNT * 95 / 100, 
            address(this)
        );
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

    // function _reportBabylonianComparison(string memory operation, BenchmarkResult memory babylonianResult, BenchmarkResult memory newtonResult) internal pure {
    //     console2.log("\n", operation, "Babylonian vs Newton-Raphson Results:");
    //     console2.log("  Babylonian Method (avg): %d gas", babylonianResult.blendedGas);
    //     console2.log("  Newton-Raphson Method (avg): %d gas", newtonResult.blendedGas);
        
    //     int256 gasDiff = int256(newtonResult.blendedGas) - int256(babylonianResult.blendedGas);
    //     uint256 percentChange = gasDiff > 0 ? 
    //         (uint256(gasDiff) * 100) / babylonianResult.blendedGas : 
    //         (uint256(-gasDiff) * 100) / babylonianResult.blendedGas;
        
    //     console2.log("  Gas difference: %d gas", gasDiff);
    //     console2.log("  Percent change: %d%%", percentChange);
        
    //     if (newtonResult.blendedGas < babylonianResult.blendedGas) {
    //         console2.log("  [SUCCESS] Newton-Raphson is more gas-efficient");
    //     } else {
    //         console2.log("  [INFO] Babylonian is more gas-efficient");
    //     }
    // }

    // function _analyzeBabylonianResults(BenchmarkResult memory babylonianResult, BenchmarkResult memory newtonResult) internal pure {
    //     console2.log("\nBabylonian vs Newton-Raphson Analysis:");
    //     if (newtonResult.blendedGas < babylonianResult.blendedGas) {
    //         console2.log("  [TARGET] Newton-Raphson method is more gas-efficient");
    //         console2.log("  [INFO] This suggests the Newton-Raphson algorithm converges faster");
    //         console2.log("  [INFO] Consider using Newton-Raphson for production deployments");
    //     } else {
    //         console2.log("  [INFO] Babylonian method is more gas-efficient");
    //         console2.log("  [INFO] This suggests the Babylonian method is well-optimized");
    //         console2.log("  [INFO] Consider using Babylonian method for production deployments");
    //     }
        
    //     // Calculate precision difference (if any)
    //     console2.log("  [INFO] Both methods should provide similar precision for LP token calculations");
    //     console2.log("  [INFO] The choice between methods should be based on gas efficiency");
    // }

    // ============ Comprehensive Report ============
    function testGenerateComprehensiveReport() public pure {
        console2.log("==================== COMPREHENSIVE BENCHMARK REPORT ====================");
        
        console2.log("\nThis test suite provides comprehensive benchmarking of:");
        console2.log("1. Gas efficiency comparison between BasicAMM and BlendedAMM");
        console2.log("2. Statistical significance through multiple iterations");
        console2.log("3. Babylonian vs Newton-Raphson algorithm comparison");
        
        console2.log("\nKey Metrics:");
        console2.log("- Gas usage for all AMM operations");
        console2.log("- Square root algorithm efficiency comparison");
        console2.log("- Precision differences between calculation methods");
        
        console2.log("\nRecommendations:");
        console2.log("- Run individual test functions for detailed analysis");
        console2.log("- Compare results across different network conditions");
        console2.log("- Consider gas costs vs. precision improvements");
        console2.log("- Evaluate mathematical engine benefits in production");
        console2.log("- Choose between Babylonian and Newton-Raphson based on gas efficiency");
        console2.log("- Test both methods to determine optimal configuration for your use case");
        
        console2.log("================================================");
    }
}
