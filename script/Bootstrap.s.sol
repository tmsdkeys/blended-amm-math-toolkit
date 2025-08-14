// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {EnhancedAMM} from "../src/EnhancedAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Bootstrap
 * @dev Initialize deployed contracts with liquidity and test accounts
 * Run this after deployment to prepare for benchmarking
 */
contract Bootstrap is Script {
    
    // Deployed contracts
    BasicAMM public basicAmm;
    EnhancedAMM public enhancedAmm;
    IERC20 public tokenA;
    IERC20 public tokenB;
    
    // Test accounts
    address public alice;
    address public bob;
    address public charlie;
    
    // Initial amounts (adjust based on your token setup)
    uint256 constant INITIAL_LIQUIDITY = 10000 * 1e18;
    uint256 constant TEST_TOKENS_PER_USER = 5000 * 1e18;
    
    function run() external {
        console.log("=== Bootstrapping Deployed Contracts ===");
        
        // Load deployment addresses
        loadDeployedContracts();
        
        // Setup test accounts
        setupTestAccounts();
        
        // Start broadcasting
        vm.startBroadcast();
        
        // Step 1: Add initial liquidity to both AMMs
        addInitialLiquidity();
        
        // Step 2: Fund test accounts with tokens
        fundTestAccounts();
        
        vm.stopBroadcast();
        
        // Step 3: Verify setup
        verifySetup();
        
        console.log("\n=== Bootstrap Complete ===");
        console.log("Ready for gas benchmarking!");
    }
    
    function loadDeployedContracts() internal {
        string memory deploymentData = vm.readFile("./deployment.json");
        
        tokenA = IERC20(vm.parseJsonAddress(deploymentData, ".tokenA"));
        tokenB = IERC20(vm.parseJsonAddress(deploymentData, ".tokenB"));
        basicAmm = BasicAMM(vm.parseJsonAddress(deploymentData, ".basicAMM"));
        enhancedAmm = EnhancedAMM(vm.parseJsonAddress(deploymentData, ".enhancedAMM"));
        
        console.log("Loaded contracts:");
        console.log("  Token A:", address(tokenA));
        console.log("  Token B:", address(tokenB));
        console.log("  Basic AMM:", address(basicAmm));
        console.log("  Enhanced AMM:", address(enhancedAmm));
    }
    
    function setupTestAccounts() internal {
        // Use deterministic addresses for consistency
        alice = vm.addr(1);
        bob = vm.addr(2);
        charlie = vm.addr(3);
        
        console.log("\nTest accounts:");
        console.log("  Alice:", alice);
        console.log("  Bob:", bob);
        console.log("  Charlie:", charlie);
    }
    
    function addInitialLiquidity() internal {
        console.log("\n=== Adding Initial Liquidity ===");
        
        // Check deployer balance
        uint256 balanceA = tokenA.balanceOf(msg.sender);
        uint256 balanceB = tokenB.balanceOf(msg.sender);
        
        console.log("Deployer Token A balance:", balanceA / 1e18);
        console.log("Deployer Token B balance:", balanceB / 1e18);
        
        require(balanceA >= INITIAL_LIQUIDITY * 2, "Insufficient Token A for bootstrap");
        require(balanceB >= INITIAL_LIQUIDITY * 2, "Insufficient Token B for bootstrap");
        
        // Approve AMMs
        tokenA.approve(address(basicAmm), INITIAL_LIQUIDITY);
        tokenB.approve(address(basicAmm), INITIAL_LIQUIDITY);
        tokenA.approve(address(enhancedAmm), INITIAL_LIQUIDITY);
        tokenB.approve(address(enhancedAmm), INITIAL_LIQUIDITY);
        
        // Add liquidity to Basic AMM
        console.log("Adding liquidity to Basic AMM...");
        uint256 basicLiquidity = basicAmm.addLiquidity(
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            msg.sender
        );
        console.log("  LP tokens received:", basicLiquidity / 1e18);
        
        // Add liquidity to Enhanced AMM
        console.log("Adding liquidity to Enhanced AMM...");
        uint256 enhancedLiquidity = enhancedAmm.addLiquidityEnhanced(
            INITIAL_LIQUIDITY,
            INITIAL_LIQUIDITY,
            0,
            0,
            msg.sender
        );
        console.log("  LP tokens received:", enhancedLiquidity / 1e18);
    }
    
    function fundTestAccounts() internal {
        console.log("\n=== Funding Test Accounts ===");
        
        // Fund Alice (liquidity provider)
        console.log("Funding Alice...");
        require(tokenA.transfer(alice, TEST_TOKENS_PER_USER), "Token A transfer to Alice failed");
        require(tokenB.transfer(alice, TEST_TOKENS_PER_USER), "Token B transfer to Alice failed");
        
        // Fund Bob (swapper)
        console.log("Funding Bob...");
        require(tokenA.transfer(bob, TEST_TOKENS_PER_USER), "Token A transfer to Bob failed");
        require(tokenB.transfer(bob, TEST_TOKENS_PER_USER), "Token B transfer to Bob failed");
        
        // Fund Charlie (additional tester)
        console.log("Funding Charlie...");
        require(tokenA.transfer(charlie, TEST_TOKENS_PER_USER / 2), "Token A transfer to Charlie failed");
        require(tokenB.transfer(charlie, TEST_TOKENS_PER_USER / 2), "Token B transfer to Charlie failed");
    }
    
    function verifySetup() internal view {
        console.log("\n=== Verifying Setup ===");
        
        // Check AMM reserves
        (uint256 basicReserve0, uint256 basicReserve1) = basicAmm.getReserves();
        console.log("Basic AMM Reserves:");
        console.log("  Token A:", basicReserve0 / 1e18);
        console.log("  Token B:", basicReserve1 / 1e18);
        
        (uint256 enhancedReserve0, uint256 enhancedReserve1) = enhancedAmm.getReserves();
        console.log("Enhanced AMM Reserves:");
        console.log("  Token A:", enhancedReserve0 / 1e18);
        console.log("  Token B:", enhancedReserve1 / 1e18);
        
        // Check test account balances
        console.log("\nTest Account Balances:");
        console.log("Alice:");
        console.log("  Token A:", tokenA.balanceOf(alice) / 1e18);
        console.log("  Token B:", tokenB.balanceOf(alice) / 1e18);
        
        console.log("Bob:");
        console.log("  Token A:", tokenA.balanceOf(bob) / 1e18);
        console.log("  Token B:", tokenB.balanceOf(bob) / 1e18);
        
        console.log("Charlie:");
        console.log("  Token A:", tokenA.balanceOf(charlie) / 1e18);
        console.log("  Token B:", tokenB.balanceOf(charlie) / 1e18);
    }
}