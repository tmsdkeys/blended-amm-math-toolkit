// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";
import {IMathematicalEngine} from "../out/MathematicalEngine.wasm/interface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title DeployedGasBenchmark
 * @dev Gas benchmarking using actual deployed contracts
 * Reads addresses from deployment.json
 */
contract DeployedGasBenchmark is Test {
    
    // Deployed contract instances
    BasicAMM public basicAmm;
    BlendedAMM public blendedAmm;
    IMathematicalEngine public mathEngine;
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    // Test accounts
    address public alice;
    address public bob;
    
    // Test amounts (adjust based on your token decimals)
    uint256 constant SWAP_AMOUNT = 100 * 1e18;
    uint256 constant LIQUIDITY_AMOUNT = 1000 * 1e18;
    
    // Gas measurements
    struct GasReport {
        uint256 basicGas;
        uint256 blendedGas;
        int256 gasDiff;
        uint256 percentSaved;
    }
    
    function setUp() public {
        console.log("=== Loading Deployed Contracts ===");
        
        // Load deployment addresses from JSON
        string memory deploymentData = vm.readFile("./deployments/testnet.json");
        
        tokenA = IERC20(vm.parseJsonAddress(deploymentData, ".tokenA"));
        tokenB = IERC20(vm.parseJsonAddress(deploymentData, ".tokenB"));
        mathEngine = IMathematicalEngine(vm.parseJsonAddress(deploymentData, ".mathEngine"));
        basicAmm = BasicAMM(vm.parseJsonAddress(deploymentData, ".basicAMM"));
        blendedAmm = BlendedAMM(vm.parseJsonAddress(deploymentData, ".blendedAMM"));
        
        console.log("Token A:", address(tokenA));
        console.log("Token B:", address(tokenB));
        console.log("Math Engine:", address(mathEngine));
        console.log("Basic AMM:", address(basicAmm));
        console.log("Blended AMM:", address(blendedAmm));
        
        // Setup test accounts with some ETH
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        
        // Note: Assumes tokens are already funded via bootstrap script
        console.log("Setup complete!");
    }
    
    function testSwapGasComparison() public {
        console.log("\n=== Swap Gas Comparison (Deployed Contracts) ===");
        
        // Ensure bob has tokens (should be done in bootstrap)
        uint256 bobBalance = tokenA.balanceOf(bob);
        console.log("Bob's Token A balance:", bobBalance / 1e18);
        require(bobBalance >= SWAP_AMOUNT, "Insufficient balance - run bootstrap first");
        
        // Approve both AMMs
        vm.startPrank(bob);
        tokenA.approve(address(basicAmm), type(uint256).max);
        tokenA.approve(address(blendedAmm), type(uint256).max);
        vm.stopPrank();
        
        // Test Basic AMM swap
        vm.prank(bob);
        uint256 gasStart = gasleft();
        basicAmm.swap(address(tokenA), SWAP_AMOUNT, 0, bob);
        uint256 basicGas = gasStart - gasleft();
        
        // Test Blended AMM swap
        vm.prank(bob);
        gasStart = gasleft();
        blendedAmm.swap(address(tokenA), SWAP_AMOUNT, 0, bob);
        uint256 blendedGas = gasStart - gasleft();
        
        // Report results
        _reportGasComparison("Swap", basicGas, blendedGas);
    }
    
    function testAddLiquidityGasComparison() public {
        console.log("\n=== Add Liquidity Gas Comparison (Deployed Contracts) ===");
        
        // Ensure alice has tokens (should be done in bootstrap)
        uint256 aliceBalanceA = tokenA.balanceOf(alice);
        uint256 aliceBalanceB = tokenB.balanceOf(alice);
        console.log("Alice's Token A balance:", aliceBalanceA / 1e18);
        console.log("Alice's Token B balance:", aliceBalanceB / 1e18);
        
        require(aliceBalanceA >= LIQUIDITY_AMOUNT * 2, "Insufficient Token A - run bootstrap");
        require(aliceBalanceB >= LIQUIDITY_AMOUNT * 2, "Insufficient Token B - run bootstrap");
        
        // Approve both AMMs
        vm.startPrank(alice);
        tokenA.approve(address(basicAmm), type(uint256).max);
        tokenB.approve(address(basicAmm), type(uint256).max);
        tokenA.approve(address(blendedAmm), type(uint256).max);
        tokenB.approve(address(blendedAmm), type(uint256).max);
        vm.stopPrank();
        
        // Test Basic AMM add liquidity
        vm.prank(alice);
        uint256 gasStart = gasleft();
        basicAmm.addLiquidity(
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT * 95 / 100,
            LIQUIDITY_AMOUNT * 95 / 100,
            alice
        );
        uint256 basicGas = gasStart - gasleft();
        
        // Test Blended AMM add liquidity
        vm.prank(alice);
        gasStart = gasleft();
        blendedAmm.addLiquidity(
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT,
            LIQUIDITY_AMOUNT * 95 / 100,
            LIQUIDITY_AMOUNT * 95 / 100,
            alice
        );
        uint256 blendedGas = gasStart - gasleft();
        
        // Report results
        _reportGasComparison("Add Liquidity", basicGas, blendedGas);
    }
    
    function testDirectMathEngineOperations() public {
        console.log("\n=== Direct Math Engine Operations ===");
        
        // Test 1: Square Root
        uint256 testValue = 1000000 * 1e18;
        uint256 gasStart = gasleft();
        uint256 sqrtResult = mathEngine.calculatePreciseSquareRoot(testValue);
        uint256 sqrtGas = gasStart - gasleft();
        console.log("Square root of 1M tokens:", sqrtResult / 1e9);
        console.log("Gas used:", sqrtGas);
        
        // Test 2: Dynamic Fee Calculation
        IMathematicalEngine.DynamicFeeParams memory feeParams = IMathematicalEngine.DynamicFeeParams({
            volatility: 200,
            volume_24h: 10000 * 1e18,
            liquidity_depth: 1000000 * 1e18
        });
        
        gasStart = gasleft();
        uint256 dynamicFee = mathEngine.calculateDynamicFee(feeParams);
        uint256 feeGas = gasStart - gasleft();
        console.log("Dynamic fee:", dynamicFee, "basis points");
        console.log("Gas used:", feeGas);
        
        // Test 3: Impermanent Loss
        uint256 initialPrice = 1 * 1e18;
        uint256 currentPrice = 15 * 1e17; // 1.5x price change
        
        gasStart = gasleft();
        uint256 il = mathEngine.calculateImpermanentLoss(initialPrice, currentPrice);
        uint256 ilGas = gasStart - gasleft();
        console.log("Impermanent loss:", il, "basis points");
        console.log("Gas used:", ilGas);
        
        console.log("\nNote: These operations are impossible or extremely expensive in pure Solidity!");
    }
    
    function testCompareWithSolidityImplementations() public {
        console.log("\n=== Solidity vs Rust Square Root ===");
        
        uint256 testValue = 625 * 1e18;
        
        // Test Solidity implementation (Babylonian method)
        uint256 gasStart = gasleft();
        uint256 solidityResult = _sqrtBabylonian(testValue);
        uint256 solidityGas = gasStart - gasleft();
        
        // Test Rust implementation
        gasStart = gasleft();
        uint256 rustResult = mathEngine.calculatePreciseSquareRoot(testValue);
        uint256 rustGas = gasStart - gasleft();
        
        console.log("Test value:", testValue / 1e18);
        console.log("Solidity result:", solidityResult / 1e9);
        console.log("Rust result:", rustResult / 1e9);
        
        _reportGasComparison("Square Root", solidityGas, rustGas);
    }
    
    // Helper function: Babylonian square root (Solidity implementation)
    function _sqrtBabylonian(uint256 x) internal pure returns (uint256 y) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
    }
    
    // Helper function: Report gas comparison
    function _reportGasComparison(
        string memory operation,
        uint256 basicGas,
        uint256 blendedGas
    ) internal pure {
        console.log("\n", operation, "Results:");
        console.log("  Basic/Solidity Gas:", basicGas);
        console.log("  Blended/Rust Gas:", blendedGas);
        
        if (blendedGas < basicGas) {
            uint256 saved = basicGas - blendedGas;
            uint256 percentSaved = (saved * 100) / basicGas;
            console.log("  Gas Saved:", saved);
            console.log("  Percent Saved:", percentSaved, "%");
        } else {
            uint256 extra = blendedGas - basicGas;
            uint256 percentExtra = (extra * 100) / basicGas;
            console.log("  Extra Gas Used:", extra);
            console.log("  Percent Increase:", percentExtra, "%");
        }
    }
}