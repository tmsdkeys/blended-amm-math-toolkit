const ethers = require("ethers");
const {
  CONFIG,
  provider,
  wallet,
  ERC20_ABI,
  BASIC_AMM_ABI,
  ENHANCED_AMM_ABI,
  formatEther,
  parseEther,
} = require("./config");

async function bootstrap() {
  console.log("=== Bootstrapping Mathematical AMM Toolkit ===\n");

  try {
    // Check network connection
    const network = await provider.getNetwork();
    console.log(`Connected to: ${network.name} (chainId: ${network.chainId})`);

    if (network.chainId !== CONFIG.chainId) {
      throw new Error(
        `Expected chainId ${CONFIG.chainId}, got ${network.chainId}`
      );
    }

    // Initialize contract instances
    const tokenA = new ethers.Contract(
      CONFIG.addresses.tokenA,
      ERC20_ABI,
      wallet
    );
    const tokenB = new ethers.Contract(
      CONFIG.addresses.tokenB,
      ERC20_ABI,
      wallet
    );
    const basicAMM = new ethers.Contract(
      CONFIG.addresses.basicAMM,
      BASIC_AMM_ABI,
      wallet
    );
    const enhancedAMM = new ethers.Contract(
      CONFIG.addresses.enhancedAMM,
      ENHANCED_AMM_ABI,
      wallet
    );

    console.log("Contract addresses:");
    console.log(`  Token A: ${CONFIG.addresses.tokenA}`);
    console.log(`  Token B: ${CONFIG.addresses.tokenB}`);
    console.log(`  Basic AMM: ${CONFIG.addresses.basicAMM}`);
    console.log(`  Enhanced AMM: ${CONFIG.addresses.enhancedAMM}`);
    console.log(`  Math Engine: ${CONFIG.addresses.mathEngine}\n`);

    // Check deployer balances
    const deployerAddress = await wallet.getAddress();
    console.log(`Deployer address: ${deployerAddress}\n`);

    const balanceA = await tokenA.balanceOf(deployerAddress);
    const balanceB = await tokenB.balanceOf(deployerAddress);

    console.log("Deployer token balances:");
    console.log(`  Token A: ${formatEther(balanceA)}`);
    console.log(`  Token B: ${formatEther(balanceB)}\n`);

    const reserve0 = await basicAMM.reserve0();
    const reserve1 = await basicAMM.reserve1();
    console.log("Reserves:", reserve0.toString(), reserve1.toString());

    // Check if we have enough tokens
    const totalNeeded = CONFIG.INITIAL_LIQUIDITY.mul(2).add(
      CONFIG.TEST_TOKENS_PER_USER.mul(6)
    ); // 2 AMMs + 3 test users * 2 tokens

    if (balanceA.lt(totalNeeded) || balanceB.lt(totalNeeded)) {
      console.log("⚠️  Insufficient token balance for bootstrap");
      console.log(`Need at least ${formatEther(totalNeeded)} of each token`);
      console.log("Note: You may need to mint more tokens first\n");
    }

    // Approve tokens for both AMMs
    console.log("=== Approving tokens for AMMs ===");

    console.log("Approving Basic AMM...");
    await (
      await tokenA.approve(
        CONFIG.addresses.basicAMM,
        ethers.constants.MaxUint256
      )
    ).wait();
    await (
      await tokenB.approve(
        CONFIG.addresses.basicAMM,
        ethers.constants.MaxUint256
      )
    ).wait();

    console.log("Approving Enhanced AMM...");
    await (
      await tokenA.approve(
        CONFIG.addresses.enhancedAMM,
        ethers.constants.MaxUint256
      )
    ).wait();
    await (
      await tokenB.approve(
        CONFIG.addresses.enhancedAMM,
        ethers.constants.MaxUint256
      )
    ).wait();

    console.log("✅ Token approvals complete\n");

    // Add initial liquidity to Basic AMM
    console.log("=== Adding Initial Liquidity ===");
    console.log("Adding liquidity to Basic AMM...");

    const basicLiquidityTx = await basicAMM.addLiquidity(
      CONFIG.INITIAL_LIQUIDITY,
      CONFIG.INITIAL_LIQUIDITY,
      0, // amount0Min
      0, // amount1Min
      deployerAddress,
      { gasLimit: 500000 } // Explicit gas limit
    );
    const basicReceipt = await basicLiquidityTx.wait();
    console.log(`  TX Hash: ${basicReceipt.transactionHash}`);
    console.log(`  Gas Used: ${basicReceipt.gasUsed.toString()}`);

    // Check LP tokens received
    const basicLPBalance = await basicAMM.balanceOf(deployerAddress);
    console.log(`  LP Tokens Received: ${formatEther(basicLPBalance)}`);

    // Add initial liquidity to Enhanced AMM
    console.log("\nAdding liquidity to Enhanced AMM...");

    const enhancedLiquidityTx = await enhancedAMM.addLiquidityEnhanced(
      CONFIG.INITIAL_LIQUIDITY,
      CONFIG.INITIAL_LIQUIDITY,
      0, // amount0Min
      0, // amount1Min
      deployerAddress,
      { gasLimit: 500000 } // Explicit gas limit
    );
    const enhancedReceipt = await enhancedLiquidityTx.wait();
    console.log(`  TX Hash: ${enhancedReceipt.transactionHash}`);
    console.log(`  Gas Used: ${enhancedReceipt.gasUsed.toString()}`);

    // Check LP tokens received
    const enhancedLPBalance = await enhancedAMM.balanceOf(deployerAddress);
    console.log(`  LP Tokens Received: ${formatEther(enhancedLPBalance)}`);

    // Verify reserves
    console.log("\n=== Verifying Reserves ===");
    const [basicReserve0, basicReserve1] = await basicAMM.getReserves();
    const [enhancedReserve0, enhancedReserve1] =
      await enhancedAMM.getReserves();

    console.log("Basic AMM Reserves:");
    console.log(`  Token A: ${formatEther(basicReserve0)}`);
    console.log(`  Token B: ${formatEther(basicReserve1)}`);

    console.log("Enhanced AMM Reserves:");
    console.log(`  Token A: ${formatEther(enhancedReserve0)}`);
    console.log(`  Token B: ${formatEther(enhancedReserve1)}\n`);

    // Fund test accounts (simulated)
    console.log("=== Test Account Setup ===");
    console.log(
      "Note: In a real scenario, you would transfer tokens to test accounts"
    );
    console.log(
      "For testing purposes, we'll use the deployer account as the tester\n"
    );

    // Display final status
    console.log("=== Bootstrap Summary ===");
    console.log("✅ Basic AMM initialized with liquidity");
    console.log("✅ Enhanced AMM initialized with liquidity");
    console.log("✅ Both AMMs have equal reserves for fair comparison");
    console.log("✅ Ready for gas benchmarking and testing\n");

    console.log("Next steps:");
    console.log("  npm run test-compare     # Compare gas usage between AMMs");
    console.log("  npm run test-math-engine # Test Rust math engine directly");
    console.log("  npm run test-basic       # Test Basic AMM functions");
    console.log("  npm run test-enhanced    # Test Enhanced AMM functions");
  } catch (error) {
    console.error("❌ Bootstrap failed:", error.message);
    if (error.transaction) {
      console.error("Transaction hash:", error.transaction.hash);
    }
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  bootstrap();
}

module.exports = { bootstrap };
