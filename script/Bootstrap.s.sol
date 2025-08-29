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

    // Test accounts
    address public alice;
    address public bob;
    address public charlie;

    // Network detection
    string public deploymentFilePath;

    // Initial amounts (adjust based on your token setup)
    uint256 constant INITIAL_LIQUIDITY = 10000 * 1e18;
    uint256 constant TEST_TOKENS_PER_USER = 5000 * 1e18;

    function run() external {
        // Detect network based on chain ID
        uint256 chainId = block.chainid;
        deploymentFilePath = getDeploymentPath();

        console.log("Detected chain ID:", chainId);
        console.log("Deployment file:", deploymentFilePath);

        console.log("=== Bootstrapping Deployed Contracts on chain", chainId, "===");

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

        console.log("\n=== Bootstrap Complete on chain", chainId, "===");
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

        // Check if we need to reset approvals (some tokens require this)
        checkAndResetApprovals();
        console.log("Adding liquidity to Basic AMM...");
        uint256 basicLiquidity = basicAmm.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, msg.sender);
        console.log("  LP tokens received:", basicLiquidity / 1e18);

        // Add liquidity to Blended AMM
        console.log("Adding liquidity to Blended AMM...");
        uint256 blendedLiquidity = blendedAmm.addLiquidity(INITIAL_LIQUIDITY, INITIAL_LIQUIDITY, 0, 0, msg.sender);
        console.log("  LP tokens received:", blendedLiquidity / 1e18);
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

        (uint256 blendedReserve0, uint256 blendedReserve1) = blendedAmm.getReserves();
        console.log("Blended AMM Reserves:");
        console.log("  Token A:", blendedReserve0 / 1e18);
        console.log("  Token B:", blendedReserve1 / 1e18);

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

        // Verify AMM approvals
        console.log("\nAMM Approvals:");
        console.log("Basic AMM Token A allowance:", tokenA.allowance(msg.sender, address(basicAmm)) / 1e18);
        console.log("Basic AMM Token B allowance:", tokenB.allowance(msg.sender, address(basicAmm)) / 1e18);
        console.log("Blended AMM Token A allowance:", tokenA.allowance(msg.sender, address(blendedAmm)) / 1e18);
        console.log("Blended AMM Token B allowance:", tokenB.allowance(msg.sender, address(blendedAmm)) / 1e18);
    }

    function getDeploymentPath() internal view returns (string memory) {
        uint256 chainId = block.chainid;

        if (chainId == 20994) {
            // testnet chain id
            return "./deployments/testnet.json";
        } else if (chainId == 20993) {
            // devnet chain id
            return "./deployments/devnet.json";
        }
        revert("Unsupported chain");
    }

    function checkAndResetApprovals() internal {
        // Some tokens require resetting approvals to 0 before setting new ones
        // Check if current allowances are sufficient, if not, reset and re-approve
        uint256 basicAllowanceA = tokenA.allowance(msg.sender, address(basicAmm));
        uint256 basicAllowanceB = tokenB.allowance(msg.sender, address(basicAmm));
        uint256 blendedAllowanceA = tokenA.allowance(msg.sender, address(blendedAmm));
        uint256 blendedAllowanceB = tokenB.allowance(msg.sender, address(blendedAmm));

        if (
            basicAllowanceA < INITIAL_LIQUIDITY || basicAllowanceB < INITIAL_LIQUIDITY
                || blendedAllowanceA < INITIAL_LIQUIDITY || blendedAllowanceB < INITIAL_LIQUIDITY
        ) {
            console.log("  Resetting approvals and re-approving...");

            // Reset to 0 first (some tokens require this)
            tokenA.approve(address(basicAmm), 0);
            tokenB.approve(address(basicAmm), 0);
            tokenA.approve(address(blendedAmm), 0);
            tokenB.approve(address(blendedAmm), 0);

            // Re-approve for max
            tokenA.approve(address(basicAmm), type(uint256).max);
            tokenB.approve(address(basicAmm), type(uint256).max);
            tokenA.approve(address(blendedAmm), type(uint256).max);
            tokenB.approve(address(blendedAmm), type(uint256).max);

            console.log("  Re-approved all AMMs for max tokens");
        }
    }
}
