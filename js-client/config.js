// Load environment variables from .env file
require("dotenv").config();

const ethers = require("ethers");
const fs = require("fs");
const path = require("path");

// Configuration
const CONFIG = {
  rpcURL: "https://rpc.testnet.fluent.xyz/",
  chainId: 20994, // Fluent testnet

  // Load from deployments/testnet.json
  addresses: {
    tokenA: "0xcB340aB3c8e00886C5DBF09328D50af6D40B9EEb",
    tokenB: "0x8108c36844Faf04C091973E95aE2B725cdCb55cC",
    mathEngine: "0x43aD2ef2fA35F2DE88E0E137429b8f6F4AeD65a2",
    basicAMM: "0x1f9483387E54577aAD7E8145E99d38D4722eaCFD",
    enhancedAMM: "0x3Ac977b824042344324C16bc0EA4B02396d94417",
  },

  // Test amounts
  INITIAL_LIQUIDITY: ethers.utils.parseEther("1000"), // 1k tokens (reduced from 10k)
  SWAP_AMOUNT: ethers.utils.parseEther("100"), // 100 tokens
  TEST_TOKENS_PER_USER: ethers.utils.parseEther("5000"), // 5k tokens per user

  // Your private key (set this as environment variable)
  privateKey:
    "8b3d42dc1cd75b54625fd098da2ad5c475bb68fabc25c256565a2581568fb0ef",
};

// Helper function to load ABI from build artifacts
function loadABI(contractName) {
  try {
    const artifactPath = path.join(
      __dirname,
      "..",
      "out",
      `${contractName}.sol`,
      `${contractName}.json`
    );
    const artifact = JSON.parse(fs.readFileSync(artifactPath, "utf8"));
    return artifact.abi;
  } catch (error) {
    console.warn(
      `Warning: Could not load ABI for ${contractName}: ${error.message}`
    );
    return [];
  }
}

// Create provider
const provider = new ethers.providers.JsonRpcProvider(CONFIG.rpcURL);

// Create wallet
const wallet = new ethers.Wallet(CONFIG.privateKey, provider);

// Load ABIs from build artifacts
const ERC20_ABI = loadABI("ERC20");
const BASIC_AMM_ABI = loadABI("BasicAMM");
const ENHANCED_AMM_ABI = loadABI("EnhancedAMM");

// Load math engine ABI from root directory
let MATH_ENGINE_ABI = [];
try {
  const mathEnginePath = path.join(__dirname, "..", "math-engine.json");
  const mathEngineArtifact = JSON.parse(
    fs.readFileSync(mathEnginePath, "utf8")
  );
  MATH_ENGINE_ABI = mathEngineArtifact.abi;
} catch (error) {
  console.warn(`Warning: Could not load math engine ABI: ${error.message}`);
}

// Helper functions
function formatEther(value) {
  return ethers.utils.formatEther(value);
}

function parseEther(value) {
  return ethers.utils.parseEther(value.toString());
}

async function getGasUsed(tx) {
  const receipt = await tx.wait();
  return receipt.gasUsed;
}

function calculateGasSavings(basicGas, enhancedGas) {
  if (basicGas.eq(0)) return "N/A";
  const diff = basicGas.sub(enhancedGas);
  const percentSaved = diff.mul(100).div(basicGas);
  return {
    saved: diff,
    percentSaved: percentSaved.toNumber(),
  };
}

module.exports = {
  CONFIG,
  provider,
  wallet,
  ERC20_ABI,
  BASIC_AMM_ABI,
  ENHANCED_AMM_ABI,
  MATH_ENGINE_ABI,
  formatEther,
  parseEther,
  getGasUsed,
  calculateGasSavings,
};
