// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BasicAMM} from "../src/BasicAMM.sol";
import {BlendedAMM} from "../src/BlendedAMM.sol";

contract Deploy is Script {
    // Deployment addresses
    address public tokenA;
    address public tokenB;
    address public mathEngine;
    address public basicAmm;
    address public blendedAmm;
    
    function run() external {
        // Start broadcasting transactions
        vm.startBroadcast();
        
        // Step 1: Deploy test tokens (or use existing ones)
        tokenA = deployTokenA();
        tokenB = deployTokenB();
        
        // Step 2: Deploy the Rust Mathematical Engine from WASM bytecode
        mathEngine = deployMathEngine();
        
        // Step 3: Deploy Basic AMM (pure Solidity baseline)
        basicAmm = address(new BasicAMM(
            tokenA,
            tokenB,
            "Basic AMM LP",
            "BASIC-LP"
        ));
        console.log("Basic AMM deployed at:", basicAmm);
        
        // Step 4: Deploy Blended AMM (with Rust math engine)
        blendedAmm = address(new BlendedAMM(
            tokenA,
            tokenB,
            mathEngine,
            "Blended AMM LP",
            "BLENDED-LP"
        ));
        console.log("Blended AMM deployed at:", blendedAmm);
        
        // Step 5: Save deployment addresses for testing
        saveDeploymentAddresses();
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Token A:", tokenA);
        console.log("Token B:", tokenB);
        console.log("Math Engine:", mathEngine);
        console.log("Basic AMM:", basicAmm);
        console.log("Blended AMM:", blendedAmm);
    }
    
    function deployTokenA() internal returns (address) {
        MockERC20 token = new MockERC20("Token A", "TKNA");
        console.log("Token A deployed at:", address(token));
        return address(token);
    }
    
    function deployTokenB() internal returns (address) {
        MockERC20 token = new MockERC20("Token B", "TKNB");
        console.log("Token B deployed at:", address(token));
        return address(token);
    }
    
    function deployMathEngine() internal returns (address) {
        // Read the WASM bytecode from the build artifact
        bytes memory wasmBytecode = vm.readFileBinary("out/MathematicalEngine.wasm/MathematicalEngine.wasm");
        
        // Deploy the WASM contract
        address deployed;
        assembly {
            deployed := create2(0, add(wasmBytecode, 0x20), mload(wasmBytecode), 0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef)
        }
        
        require(deployed != address(0), "Failed to deploy Math Engine");
        console.log("Math Engine deployed at:", deployed);
        
        return deployed;
    }
    
    function saveDeploymentAddresses() internal {
        // Save to a JSON file for easy access in tests
        string memory json = "deployment";
        vm.serializeAddress(json, "tokenA", tokenA);
        vm.serializeAddress(json, "tokenB", tokenB);
        vm.serializeAddress(json, "mathEngine", mathEngine);
        vm.serializeAddress(json, "basicAMM", basicAmm);
        string memory finalJson = vm.serializeAddress(json, "blendedAMM", blendedAmm);
        
        vm.writeJson(finalJson, "./deployment.json");
        console.log("Deployment addresses saved to deployment.json");
    }
}

// Simple mock ERC20 for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        // Mint initial supply to deployer
        totalSupply = 1000000 * 10**18;
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }
    
    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
    
    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        require(balanceOf[from] >= amount, "Insufficient balance");
        require(allowance[from][msg.sender] >= amount, "Insufficient allowance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        allowance[from][msg.sender] -= amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        totalSupply += amount;
        emit Transfer(address(0), to, amount);
    }
}