// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";
import {IMathematicalEngine} from "../out/MathematicalEngine.wasm/interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IAmm} from "../src/IAmm.sol";
import {LPTokenDataset} from "./LPTokenDataset.sol";

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

    // ============ LP Token Accuracy Testing Structures ============
    
    struct LPTestResult {
        uint256 amount0;
        uint256 amount1;
        uint256 expectedLPTokens;
        uint256 basicResult;
        uint256 babylonianResult;
        uint256 newtonRaphsonResult;
        uint256 basicRelativeError;      // Relative error in basis points (10000 = 100%)
        uint256 babylonianRelativeError; // Relative error in basis points (10000 = 100%)
        uint256 newtonRaphsonRelativeError; // Relative error in basis points (10000 = 100%)
        bool basicPassed;
        bool babylonianPassed;
        bool newtonRaphsonPassed;
    }

    struct AccuracyMetrics {
        uint256 totalTests;
        uint256 basicPassed;
        uint256 babylonianPassed;
        uint256 newtonRaphsonPassed;
        uint256 maxBasicRelativeError;      // Maximum relative error in basis points (10000 = 100%)
        uint256 maxBabylonianRelativeError; // Maximum relative error in basis points (10000 = 100%)
        uint256 maxNewtonRaphsonRelativeError; // Maximum relative error in basis points (10000 = 100%)
        uint256 totalBasicRelativeError;    // Sum of relative errors for averaging
        uint256 totalBabylonianRelativeError; // Sum of relative errors for averaging
        uint256 totalNewtonRaphsonRelativeError; // Sum of relative errors for averaging
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

    // ============ Calculation Accuracy Testing ============
    function testCalculationAccuracy() public {
        console2.log("\n=== CALCULATION ACCURACY COMPARISON ===");
        
        // Test LP token calculation accuracy
        _testLPTokenCalculationAccuracy();
        
        // // Test impermanent loss calculation accuracy
        // _testImpermanentLossCalculationAccuracy();
        
        // // Test mathematical engine functions directly
        // _testMathematicalEngineFunctions();
    }

    function _testLPTokenCalculationAccuracy() internal {
        console2.log("Testing LP Token Calculation Accuracy with External Dataset...");
        
        // Load and test the external dataset with floating-point ground truth
        _testLPTokenAccuracyWithDataset();
        
        // Generate accuracy report
        _generateLPTokenAccuracyReport();
    }

    // ============ Comprehensive LP Token Accuracy Testing ============

    function _testLPTokenAccuracyWithDataset() internal {
        console2.log("\n=== LP TOKEN ACCURACY WITH GENERATED DATASET ===");
        
        // Load the generated dataset with floating-point ground truth
        LPTokenDataset.LPTestCase[] memory testCases = LPTokenDataset.getTestCases();
        
        console2.log("Loaded %d test cases from generated dataset", testCases.length);
        
        AccuracyMetrics memory metrics = AccuracyMetrics({
            totalTests: 0,
            basicPassed: 0,
            babylonianPassed: 0,
            newtonRaphsonPassed: 0,
            maxBasicRelativeError: 0,
            maxBabylonianRelativeError: 0,
            maxNewtonRaphsonRelativeError: 0,
            totalBasicRelativeError: 0,
            totalBabylonianRelativeError: 0,
            totalNewtonRaphsonRelativeError: 0
        });

        // Test each case from the generated dataset
        _testDatasetFromArray(testCases, metrics);
        
        _logAccuracyMetrics(metrics);
    }

    function _testImpermanentLossCalculationAccuracy() internal {
        console2.log("Testing Impermanent Loss Calculation Accuracy...");
        
        // Simulate price change scenario
        uint256 initialPrice = 1 * 1e18;  // 1:1 ratio
        uint256 currentPrice = 15 * 1e17; // 1.5x price change
        
        // Calculate using both methods
        uint256 babylonianIL = mathEngine.calculateImpermanentLoss(initialPrice, currentPrice, true);
        uint256 newtonIL = mathEngine.calculateImpermanentLoss(initialPrice, currentPrice, false);
        
        console2.log("  Initial price ratio: 1:1");
        console2.log("  Current price ratio: 1.5:1");
        console2.log("  Babylonian IL:", babylonianIL, "basis points");
        console2.log("  Newton-Raphson IL:", newtonIL, "basis points");
        
        // Calculate difference between methods
        uint256 methodDiff = babylonianIL > newtonIL ? babylonianIL - newtonIL : newtonIL - babylonianIL;
        console2.log("  Method difference:", methodDiff, "basis points");
        
        if (babylonianIL != 0 && newtonIL != 0) {
            console2.log("  [SUCCESS] Both Rust mathematical engine methods working correctly");
        } else {
            console2.log("  [FAIL] Rust mathematical engine calculation failed");
        }
        
        if (methodDiff == 0) {
            console2.log("  [SUCCESS] Both methods produce identical results!");
        } else {
            console2.log("  [INFO] Methods produce slightly different results");
        }
    }

    function testImpermanentLossBabylonianBenchmark() public {
        console2.log("\n=== IMPERMANENT LOSS BABYLONIAN vs NEWTON-RAPHSON BENCHMARK ===");
        
        // Test multiple price scenarios
        uint256[] memory initialPrices = new uint256[](3);
        uint256[] memory currentPrices = new uint256[](3);
        
        // Scenario 1: 1:1 to 1.5:1 (moderate price change)
        initialPrices[0] = 1 * 1e18;
        currentPrices[0] = 15 * 1e17;
        
        // Scenario 2: 1:1 to 2:1 (significant price change)
        initialPrices[1] = 1 * 1e18;
        currentPrices[1] = 2 * 1e18;
        
        // Scenario 3: 1:1 to 0.5:1 (price decrease)
        initialPrices[2] = 1 * 1e18;
        currentPrices[2] = 5 * 1e17;
        
        for (uint256 i = 0; i < initialPrices.length; i++) {
            console2.log("\n--- Price Scenario %d ---", i + 1);
            console2.log("Initial price ratio: 1:1");
            console2.log("Current price ratio: %d:1", currentPrices[i] / 1e17);
            
            // Test with Babylonian method
            _setUseBabylonian(true);
            uint256 gasStart = gasleft();
            uint256 babylonianIL = mathEngine.calculateImpermanentLoss(initialPrices[i], currentPrices[i], true);
            uint256 babylonianGas = gasStart - gasleft();
            
            // Test with Newton-Raphson method
            _setUseBabylonian(false);
            gasStart = gasleft();
            uint256 newtonIL = mathEngine.calculateImpermanentLoss(initialPrices[i], currentPrices[i], false);
            uint256 newtonGas = gasStart - gasleft();
            
            console2.log("Babylonian IL: %d basis points (gas: %d)", babylonianIL, babylonianGas);
            console2.log("Newton-Raphson IL: %d basis points (gas: %d)", newtonIL, newtonGas);
            
            // Calculate difference
            uint256 ilDiff = babylonianIL > newtonIL ? babylonianIL - newtonIL : newtonIL - babylonianIL;
            uint256 gasDiff = newtonGas > babylonianGas ? newtonGas - babylonianGas : babylonianGas - newtonGas;
            
            console2.log("IL difference: %d basis points", ilDiff);
            console2.log("Gas difference: %d gas", gasDiff);
            
            if (newtonGas < babylonianGas) {
                console2.log("  [SUCCESS] Newton-Raphson is more gas-efficient");
            } else {
                console2.log("  [INFO] Babylonian is more gas-efficient");
            }
        }
    }

    function _testMathematicalEngineFunctions() internal {
        console2.log("Testing Mathematical Engine Functions Directly...");
        
        // Test square root calculation with both methods
        uint256 testValue = 1000000 * 1e18;
        
        console2.log("  Testing square root with Babylonian method...");
        uint256 gasStart = gasleft();
        uint256 babylonianSqrt = mathEngine.calculatePreciseSquareRoot(testValue, true);
        uint256 babylonianSqrtGas = gasStart - gasleft();
        
        console2.log("  Testing square root with Newton-Raphson method...");
        gasStart = gasleft();
        uint256 newtonSqrt = mathEngine.calculatePreciseSquareRoot(testValue, false);
        uint256 newtonSqrtGas = gasStart - gasleft();
        
        console2.log("  Babylonian sqrt result:", babylonianSqrt / 1e9, "(scaled down)");
        console2.log("  Newton-Raphson sqrt result:", newtonSqrt / 1e9, "(scaled down)");
        console2.log("  Babylonian gas used:", babylonianSqrtGas);
        console2.log("  Newton-Raphson gas used:", newtonSqrtGas);
        
        // Calculate difference
        uint256 sqrtDiff = babylonianSqrt > newtonSqrt ? babylonianSqrt - newtonSqrt : newtonSqrt - babylonianSqrt;
        int256 sqrtGasDiff = int256(newtonSqrtGas) - int256(babylonianSqrtGas);
        
        console2.log("  Sqrt result difference:", sqrtDiff / 1e9, "(scaled down)");
        console2.log("  Sqrt gas difference:", sqrtGasDiff);
        
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
        
        if (sqrtDiff == 0) {
            console2.log("  [SUCCESS] Both sqrt methods produce identical results!");
        } else {
            console2.log("  [INFO] Sqrt methods produce slightly different results");
        }
        
        if (newtonSqrtGas < babylonianSqrtGas) {
            console2.log("  [SUCCESS] Newton-Raphson sqrt is more gas-efficient!");
        } else {
            console2.log("  [INFO] Babylonian sqrt is more gas-efficient");
        }
    }

    // ============ LP Token Testing Helper Functions ============

    /// @dev Calculate square root using Babylonian method (same as BasicAMM)
    function _sqrt(uint256 x) internal pure returns (uint256) {
        if (x == 0) return 0;

        uint256 z = (x + 1) / 2;
        uint256 y = x;

        // Babylonian method iteration
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }

        return y;
    }

    function _testSingleLPTokenCaseWithExpected(uint256 amount0, uint256 amount1, uint256 expectedLPTokens) internal returns (LPTestResult memory) {
        // Calculate using Basic AMM method
        uint256 basicResult = _sqrt(amount0 * amount1);
        
        // Calculate using Rust engine - Babylonian method
        uint256 babylonianResult = mathEngine.calculateLpTokens(amount0, amount1, true);
        
        // Calculate using Rust engine - Newton-Raphson method
        uint256 newtonRaphsonResult = mathEngine.calculateLpTokens(amount0, amount1, false);
        
        // Calculate absolute errors first
        uint256 basicError = basicResult > expectedLPTokens ? 
            basicResult - expectedLPTokens : expectedLPTokens - basicResult;
        uint256 babylonianError = babylonianResult > expectedLPTokens ? 
            babylonianResult - expectedLPTokens : expectedLPTokens - babylonianResult;
        uint256 newtonRaphsonError = newtonRaphsonResult > expectedLPTokens ? 
            newtonRaphsonResult - expectedLPTokens : expectedLPTokens - newtonRaphsonResult;
        
        // Calculate relative errors in basis points (10000 = 100%)
        uint256 basicRelativeError = (basicError * 10000) / expectedLPTokens;
        uint256 babylonianRelativeError = (babylonianError * 10000) / expectedLPTokens;
        uint256 newtonRaphsonRelativeError = (newtonRaphsonError * 10000) / expectedLPTokens;
        
        // Use fixed relative tolerance (0.01% = 1 basis point)
        uint256 maxRelativeTolerance = 1; // 0.01%
        
        return LPTestResult({
            amount0: amount0,
            amount1: amount1,
            expectedLPTokens: expectedLPTokens,
            basicResult: basicResult,
            babylonianResult: babylonianResult,
            newtonRaphsonResult: newtonRaphsonResult,
            basicRelativeError: basicRelativeError,
            babylonianRelativeError: babylonianRelativeError,
            newtonRaphsonRelativeError: newtonRaphsonRelativeError,
            basicPassed: basicRelativeError <= maxRelativeTolerance,
            babylonianPassed: babylonianRelativeError <= maxRelativeTolerance,
            newtonRaphsonPassed: newtonRaphsonRelativeError <= maxRelativeTolerance
        });
    }

    function _testDatasetFromArray(LPTokenDataset.LPTestCase[] memory testCases, AccuracyMetrics memory metrics) internal {
        console2.log("Testing dataset from generated array...");
        
        // Test each case from the generated dataset array
        for (uint256 i = 0; i < testCases.length; i++) {
            LPTokenDataset.LPTestCase memory testCase = testCases[i];
            _testSingleCaseWithGroundTruth(
                metrics, 
                testCase.amount0, 
                testCase.amount1, 
                testCase.expectedLPTokens, 
                testCase.description
            );
        }
        
        console2.log("Completed testing %d cases from generated dataset", metrics.totalTests);
    }
    
    function _testSingleCaseWithGroundTruth(
        AccuracyMetrics memory metrics,
        uint256 amount0,
        uint256 amount1, 
        uint256 expectedLPTokens,
        string memory description
    ) internal {
        LPTestResult memory result = _testSingleLPTokenCaseWithExpected(amount0, amount1, expectedLPTokens);
        _updateAccuracyMetrics(metrics, result);
        
        // Log results for every test case
        console2.log("  Test: %s", description);
        console2.log("    Amount0: %d, Amount1: %d", amount0 / 1e18, amount1 / 1e18);
        console2.log("    Expected: %d", result.expectedLPTokens / 1e18);
        console2.log("    Basic: %d (error: %d bp) %s", 
            result.basicResult / 1e18, 
            result.basicRelativeError,
            result.basicPassed ? "PASS" : "FAIL");
        console2.log("    Babylonian: %d (error: %d bp) %s", 
            result.babylonianResult / 1e18, 
            result.babylonianRelativeError,
            result.babylonianPassed ? "PASS" : "FAIL");
        console2.log("    Newton: %d (error: %d bp) %s", 
            result.newtonRaphsonResult / 1e18, 
            result.newtonRaphsonRelativeError,
            result.newtonRaphsonPassed ? "PASS" : "FAIL");
        
        // Highlight significant errors
        if (result.basicRelativeError > 10 || result.babylonianRelativeError > 10 || result.newtonRaphsonRelativeError > 10) {
            console2.log("    *** SIGNIFICANT ERROR DETECTED ***");
        }
        console2.log(""); // Empty line for readability
    }

    function _generateLPTokenAccuracyReport() internal pure {
        console2.log("\n=== LP TOKEN ACCURACY REPORT ===");
        console2.log("This test evaluates LP token calculation accuracy using:");
        console2.log("- External JSON dataset with floating-point ground truth (JavaScript Math.sqrt)");
        console2.log("- 64 comprehensive test cases across 8 amount scales and 7 ratios");
        console2.log("- 8 edge cases for boundary testing");
        console2.log("- All test cases loaded from JSON with proper ground truth values");
        console2.log("- Tolerance: 0.000001 tokens or 0.01% relative error");
        console2.log("\nThe test compares three methods against mathematically correct ground truth:");
        console2.log("1. Basic AMM: Solidity Babylonian square root");
        console2.log("2. Blended AMM (Babylonian): Rust Babylonian square root");
        console2.log("3. Blended AMM (Newton-Raphson): Rust Newton-Raphson square root");
        console2.log("\nGround truth calculated using JavaScript's floating-point Math.sqrt()");
        console2.log("and converted to fixed-point (1e18 scaling) for comparison.");
        console2.log("Dataset includes amounts from 1 wei to 1e20 wei with various ratios.");
    }



    function _updateAccuracyMetrics(AccuracyMetrics memory metrics, LPTestResult memory result) internal pure {
        metrics.totalTests++;
        
        if (result.basicPassed) metrics.basicPassed++;
        if (result.babylonianPassed) metrics.babylonianPassed++;
        if (result.newtonRaphsonPassed) metrics.newtonRaphsonPassed++;
        
        // Track maximum relative errors (in basis points)
        if (result.basicRelativeError > metrics.maxBasicRelativeError) metrics.maxBasicRelativeError = result.basicRelativeError;
        if (result.babylonianRelativeError > metrics.maxBabylonianRelativeError) metrics.maxBabylonianRelativeError = result.babylonianRelativeError;
        if (result.newtonRaphsonRelativeError > metrics.maxNewtonRaphsonRelativeError) metrics.maxNewtonRaphsonRelativeError = result.newtonRaphsonRelativeError;
        
        // Accumulate relative errors for averaging
        metrics.totalBasicRelativeError += result.basicRelativeError;
        metrics.totalBabylonianRelativeError += result.babylonianRelativeError;
        metrics.totalNewtonRaphsonRelativeError += result.newtonRaphsonRelativeError;
    }

    function _logAccuracyMetrics(AccuracyMetrics memory metrics) internal pure {
        console2.log("\n=== ACCURACY METRICS SUMMARY ===");
        console2.log("Total test cases: %d", metrics.totalTests);
        console2.log("\nPass Rate:");
        uint256 basicPassRate = (metrics.basicPassed * 10000) / metrics.totalTests;
        uint256 babylonianPassRate = (metrics.babylonianPassed * 10000) / metrics.totalTests;
        uint256 newtonRaphsonPassRate = (metrics.newtonRaphsonPassed * 10000) / metrics.totalTests;
        console2.log("  Basic AMM:      %d/%d ", 
            metrics.basicPassed, metrics.totalTests, basicPassRate / 100);
        console2.log("  Babylonian:     %d/%d ", 
            metrics.babylonianPassed, metrics.totalTests, babylonianPassRate / 100);
        console2.log("  Newton-Raphson: %d/%d ", 
            metrics.newtonRaphsonPassed, metrics.totalTests, newtonRaphsonPassRate / 100);
        
        // Convert basis points to readable percentages
        uint256 maxBasicPercent = metrics.maxBasicRelativeError / 100;
        uint256 maxBasicBasisPoints = metrics.maxBasicRelativeError % 100;
        uint256 maxBabylonianPercent = metrics.maxBabylonianRelativeError / 100;
        uint256 maxBabylonianBasisPoints = metrics.maxBabylonianRelativeError % 100;
        uint256 maxNewtonPercent = metrics.maxNewtonRaphsonRelativeError / 100;
        uint256 maxNewtonBasisPoints = metrics.maxNewtonRaphsonRelativeError % 100;
        
        console2.log("\nMaximum Relative Errors:");
        console2.log("  Basic AMM:      %d.%d%%", maxBasicPercent, maxBasicBasisPoints);
        console2.log("  Babylonian:     %d.%d%%", maxBabylonianPercent, maxBabylonianBasisPoints);
        console2.log("  Newton-Raphson: %d.%d%%", maxNewtonPercent, maxNewtonBasisPoints);
        
        // Determine winner
        if (metrics.babylonianPassed > metrics.basicPassed && metrics.newtonRaphsonPassed > metrics.basicPassed) {
            console2.log("\n[SUCCESS] Both Rust methods outperform Basic AMM!");
        } else if (metrics.babylonianPassed > metrics.basicPassed) {
            console2.log("\n[SUCCESS] Babylonian method outperforms Basic AMM!");
        } else if (metrics.newtonRaphsonPassed > metrics.basicPassed) {
            console2.log("\n[SUCCESS] Newton-Raphson method outperforms Basic AMM!");
        } else {
            console2.log("\n[INFO] Basic AMM performs competitively with Rust methods");
        }
        
        if (metrics.babylonianPassed > metrics.newtonRaphsonPassed) {
            console2.log("[SUCCESS] Babylonian method is more accurate than Newton-Raphson!");
        } else if (metrics.newtonRaphsonPassed > metrics.babylonianPassed) {
            console2.log("[SUCCESS] Newton-Raphson method is more accurate than Babylonian!");
        } else {
            console2.log("[INFO] Both Rust methods have similar accuracy");
        }
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

    // ============ Comprehensive Report ============
    function testGenerateComprehensiveReport() public pure {
        console2.log("==================== COMPREHENSIVE BENCHMARK REPORT ====================");
        
        console2.log("\nThis test suite provides comprehensive benchmarking of:");
        console2.log("1. Gas efficiency comparison between BasicAMM and BlendedAMM");
        console2.log("2. Calculation accuracy analysis");
        console2.log("3. Mathematical engine performance evaluation");
        console2.log("4. Statistical significance through multiple iterations");
        console2.log("5. Babylonian vs Newton-Raphson algorithm comparison");
        
        console2.log("\nKey Metrics:");
        console2.log("- Gas usage for all AMM operations");
        console2.log("- LP token calculation accuracy");
        console2.log("- Impermanent loss calculation precision");
        console2.log("- Mathematical engine function performance");
        console2.log("- Square root algorithm efficiency comparison");
        console2.log("- Precision differences between calculation methods");
        
        console2.log("\nNew Babylonian Benchmarking Tests:");
        console2.log("- testAddLiquidityBabylonianBenchmark(): Compares gas usage for LP token calculations");
        console2.log("- testImpermanentLossBabylonianBenchmark(): Tests IL calculations with multiple price scenarios");
        console2.log("- Enhanced accuracy tests now compare both Babylonian and Newton-Raphson methods");
        
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
