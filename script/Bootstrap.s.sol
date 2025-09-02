// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title Bootstrap
 * @dev Initialize deployed contracts with liquidity and test accounts
 * Run this after deployment to prepare for benchmarking
 */
contract Bootstrap is Script {
    // Deployed contracts
    BasicAMM public basicAmm;
    BlendedAMM public blendedAmm;
    IERC20 public tokenA;
    IERC20 public tokenB;

    // Deployment configuration
    string public deploymentFilePath;

    // Initial amounts (adjust based on your token setup)
    uint256 constant INITIAL_LIQUIDITY = 10000 * 1e18;
    uint256 constant TEST_TOKENS_PER_USER = 5000 * 1e18;

    function run() external {
        // Get deployment path from environment variable
        deploymentFilePath = vm.envString("DEPLOYMENT_PATH");
        console.log("Deployment file:", deploymentFilePath);

        console.log("=== Bootstrapping Deployed Contracts ===");

        // Load deployment addresses
        loadDeployedContracts();

        // Start broadcasting
        vm.startBroadcast();

        // Step 1: Add initial liquidity to both AMMs
        addInitialLiquidity();

        vm.stopBroadcast();

        // Step 3: Verify setup
        verifySetup();

        console.log("\n=== Bootstrap Complete ===");
        console.log("Ready for gas benchmarking!");
    }

    function loadDeployedContracts() internal {
        string memory deploymentData = vm.readFile(deploymentFilePath);

        tokenA = IERC20(vm.parseJsonAddress(deploymentData, ".tokenA"));
        tokenB = IERC20(vm.parseJsonAddress(deploymentData, ".tokenB"));
        basicAmm = BasicAMM(vm.parseJsonAddress(deploymentData, ".basicAMM"));
        blendedAmm = BlendedAMM(vm.parseJsonAddress(deploymentData, ".blendedAMM"));

        console.log("Loaded contracts from", deploymentFilePath);
        console.log("  Token A:", address(tokenA));
        console.log("  Token B:", address(tokenB));
        console.log("  Basic AMM:", address(basicAmm));
        console.log("  Blended AMM:", address(blendedAmm));
    }

    function addInitialLiquidity() internal {
        console.log("\n=== Adding Initial Liquidity ===");

        // Check deployer balance (msg.sender should be your account when run with --broadcast)
        uint256 balanceA = tokenA.balanceOf(msg.sender);
        uint256 balanceB = tokenB.balanceOf(msg.sender);

        console.log("Deployer address (msg.sender):", msg.sender);
        console.log("Deployer Token A balance:", balanceA / 1e18);
        console.log("Deployer Token B balance:", balanceB / 1e18);

        require(balanceA >= INITIAL_LIQUIDITY * 2, "Insufficient Token A for bootstrap");
        require(balanceB >= INITIAL_LIQUIDITY * 2, "Insufficient Token B for bootstrap");

        // Approve AMMs for maximum token expenditures
        console.log("Approving AMM contracts for token expenditures...");

        // Approve Basic AMM
        tokenA.approve(address(basicAmm), type(uint256).max);
        tokenB.approve(address(basicAmm), type(uint256).max);
        console.log("  Approved Basic AMM for max Token A & B");

        // Approve Blended AMM
        tokenA.approve(address(blendedAmm), type(uint256).max);
        tokenB.approve(address(blendedAmm), type(uint256).max);
        console.log("  Approved Blended AMM for max Token A & B");

        // Verify approvals
        console.log("  Basic AMM Token A allowance:", tokenA.allowance(msg.sender, address(basicAmm)) / 1e18);
        console.log("  Basic AMM Token B allowance:", tokenB.allowance(msg.sender, address(basicAmm)) / 1e18);
        console.log("  Blended AMM Token A allowance:", tokenA.allowance(msg.sender, address(blendedAmm)) / 1e18);
        console.log("  Blended AMM Token B allowance:", tokenB.allowance(msg.sender, address(blendedAmm)) / 1e18);

        console.log("Adding liquidity to Basic AMM...");
        uint256 basicLiquidity = basicAmm.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, msg.sender);
        console.log("  LP tokens received:", basicLiquidity / 1e18);

        // Add liquidity to Blended AMM
        console.log("Adding liquidity to Blended AMM...");
        uint256 blendedLiquidity = blendedAmm.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, msg.sender);
        console.log("  LP tokens received:", blendedLiquidity / 1e18);
    }

    function verifySetup() internal view {
        console.log("\n=== Verifying Setup ===");

        // Check AMM reserves
        (uint256 basicReserve0, uint256 basicReserve1) = basicAmm.getReserves();
        console.log("Basic AMM Reserves:");
        console.log("  Token A:", basicReserve0 / 1e18);
        console.log("  Token B:", basicReserve1 / 1e18);

        (uint256 blendedReserve0, uint256 blendedReserve1) = blendedAmm.getReserves();
        console.log("Blended AMM Reserves:");
        console.log("  Token A:", blendedReserve0 / 1e18);
        console.log("  Token B:", blendedReserve1 / 1e18);

        // Verify AMM approvals
        console.log("\nAMM Approvals:");
        console.log("Basic AMM Token A allowance:", tokenA.allowance(msg.sender, address(basicAmm)) / 1e18);
        console.log("Basic AMM Token B allowance:", tokenB.allowance(msg.sender, address(basicAmm)) / 1e18);
        console.log("Blended AMM Token A allowance:", tokenA.allowance(msg.sender, address(blendedAmm)) / 1e18);
        console.log("Blended AMM Token B allowance:", tokenB.allowance(msg.sender, address(blendedAmm)) / 1e18);
    }
}
