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
    tokenA: "0xa37f1A5eedfb1D4e81AbE78c4B4b28c91744D1ab",
    tokenB: "0x3785F7f6046f4401b6a7cC94397ecb42A26C7fD5",
    mathEngine: "0x60c026DEF86C3D0c7d47D260dB3010775d26a535",
    basicAMM: "0x35F8e9415caBb09F4FE9Fbb4d1955D1F076292c0",
    enhancedAMM: "0x822cC306D92026cA0248941Cf7De7813faA27146",
  },

  // Test amounts
  INITIAL_LIQUIDITY: ethers.utils.parseEther("10000"), // 1k tokens (reduced from 10k)
  SWAP_AMOUNT: ethers.utils.parseEther("100"), // 100 tokens
  TEST_TOKENS_PER_USER: ethers.utils.parseEther("5000"), // 5k tokens per user

  // Your private key (set this as environment variable)
  privateKey:
    "a1c70c54fe8100c7f9dc6f9788877f4cf4a1fedba75325c60dd38fd779ade279",
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
