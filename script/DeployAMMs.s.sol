// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";

contract DeployAMMs is Script {
    // Deployment addresses
    address public tokenA;
    address public tokenB;
    address public mathEngine;
    address public basicAmm;
    address public blendedAmm;

    // Deployment configuration
    string public deploymentFilePath;

    function run() external {
        console.log("=== Starting AMM Deployment ===");
        
        // Get deployment path from environment variable
        try vm.envString("DEPLOYMENT_PATH") returns (string memory path) {
            deploymentFilePath = path;
            console.log("DEPLOYMENT_PATH environment variable found:", deploymentFilePath);
        } catch {
            revert("DEPLOYMENT_PATH environment variable is required");
        }
        
        // Validate deployment file path
        require(bytes(deploymentFilePath).length > 0, "DEPLOYMENT_PATH environment variable is required");
        
        // Verify the deployment file exists and is readable
        console.log("Attempting to read deployment file:", deploymentFilePath);
        try vm.readFile(deploymentFilePath) returns (string memory deploymentData) {
            require(bytes(deploymentData).length > 0, "Deployment file is empty");
            console.log("Deployment file loaded successfully, size:", bytes(deploymentData).length, "bytes");
        } catch {
            revert("Cannot read deployment file - check if file exists and is accessible");
        }

        // Load existing contract addresses
        console.log("Loading existing contract addresses...");
        loadExistingAddresses();
        console.log("Existing addresses loaded:");
        console.log("  Token A:", tokenA);
        console.log("  Token B:", tokenB);
        console.log("  Math Engine:", mathEngine);

        console.log("=== Deploying AMM Contracts ===");

        // Start broadcasting transactions
        vm.startBroadcast();
        console.log("Started broadcasting transactions");

        // Step 1: Deploy Basic AMM (pure Solidity baseline)
        console.log("Step 1: Deploying Basic AMM...");
        basicAmm = address(new BasicAMM(tokenA, tokenB, "Basic AMM LP", "BASIC-LP"));
        console.log("Basic AMM deployed at:", basicAmm);

        // Step 2: Deploy Blended AMM (with Rust math engine)
        console.log("Step 2: Deploying Blended AMM...");
        blendedAmm = address(new BlendedAMM(tokenA, tokenB, mathEngine, "Blended AMM LP", "BLENDED-LP"));
        console.log("Blended AMM deployed at:", blendedAmm);

        // Step 3: Save deployment addresses for testing
        console.log("Step 3: Saving deployment addresses...");
        saveDeploymentAddresses();
        console.log("Deployment addresses saved");

        vm.stopBroadcast();
        console.log("Stopped broadcasting transactions");

        console.log("\n=== AMM Deployment Complete ===");
        console.log("Token A:", tokenA);
        console.log("Token B:", tokenB);
        console.log("Math Engine:", mathEngine);
        console.log("Basic AMM:", basicAmm);
        console.log("Blended AMM:", blendedAmm);
        console.log("Deployment saved to:", deploymentFilePath);
    }

    function loadExistingAddresses() internal {
        string memory deploymentData = vm.readFile(deploymentFilePath);
        
        // Load token addresses
        tokenA = vm.parseJsonAddress(deploymentData, ".tokenA");
        tokenB = vm.parseJsonAddress(deploymentData, ".tokenB");
        mathEngine = vm.parseJsonAddress(deploymentData, ".mathEngine");
        
        // Validate addresses
        require(tokenA != address(0), "Token A address is required and cannot be zero");
        require(tokenB != address(0), "Token B address is required and cannot be zero");
        require(mathEngine != address(0), "Math engine address is required and cannot be zero");
        require(tokenA != tokenB, "Token A and Token B must be different");
    }

    function saveDeploymentAddresses() internal {    
        // Create new JSON with updated AMM addresses
        string memory json = "deployment";
        vm.serializeAddress(json, "tokenA", tokenA);
        vm.serializeAddress(json, "tokenB", tokenB);
        vm.serializeAddress(json, "mathEngine", mathEngine);
        vm.serializeAddress(json, "basicAMM", basicAmm);
        string memory finalJson = vm.serializeAddress(json, "blendedAMM", blendedAmm);

        vm.writeJson(finalJson, deploymentFilePath);
        console.log("Deployment addresses saved to", deploymentFilePath);
    }
}
