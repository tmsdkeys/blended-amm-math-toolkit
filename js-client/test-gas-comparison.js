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
  getGasUsed,
  calculateGasSavings,
} = require("./config");

class GasBenchmark {
  constructor() {
    this.results = [];
  }

  async recordTest(name, basicTx, enhancedTx, description = "") {
    const basicGas = await getGasUsed(basicTx);
    const enhancedGas = await getGasUsed(enhancedTx);
    const savings = calculateGasSavings(basicGas, enhancedGas);

    const result = {
      name,
      description,
      basicGas: basicGas.toString(),
      enhancedGas: enhancedGas.toString(),
      savings: savings.saved ? savings.saved.toString() : "0",
      percentSaved: savings.percentSaved || 0,
    };

    this.results.push(result);

    console.log(`\n=== ${name} ===`);
    if (description) console.log(description);
    console.log(`Basic AMM Gas:    ${basicGas.toString()}`);
    console.log(`Enhanced AMM Gas: ${enhancedGas.toString()}`);

    if (savings.percentSaved > 0) {
      console.log(
        `✅ Gas Saved:     ${savings.saved.toString()} (${
          savings.percentSaved
        }%)`
      );
    } else if (savings.percentSaved < 0) {
      console.log(
        `❌ Extra Gas:     ${Math.abs(savings.percentSaved)}% more gas used`
      );
    } else {
      console.log(`➖ Similar Gas:   No significant difference`);
    }

    return result;
  }

  printSummary() {
    console.log("\n" + "=".repeat(80));
    console.log("                          GAS BENCHMARK SUMMARY");
    console.log("=".repeat(80));

    let totalBasicGas = ethers.BigNumber.from(0);
    let totalEnhancedGas = ethers.BigNumber.from(0);

    this.results.forEach((result) => {
      totalBasicGas = totalBasicGas.add(result.basicGas);
      totalEnhancedGas = totalEnhancedGas.add(result.enhancedGas);

      const name = result.name.padEnd(25);
      const basicGas = result.basicGas.padStart(10);
      const enhancedGas = result.enhancedGas.padStart(10);
      const savings =
        result.percentSaved >= 0
          ? `+${result.percentSaved}%`.padStart(8)
          : `${result.percentSaved}%`.padStart(8);

      console.log(`${name} | ${basicGas} | ${enhancedGas} | ${savings}`);
    });

    console.log("-".repeat(80));
    const overallSavings = calculateGasSavings(totalBasicGas, totalEnhancedGas);
    const totalBasic = totalBasicGas.toString().padStart(10);
    const totalEnhanced = totalEnhancedGas.toString().padStart(10);
    const totalSaved =
      overallSavings.percentSaved >= 0
        ? `+${overallSavings.percentSaved}%`.padStart(8)
        : `${overallSavings.percentSaved}%`.padStart(8);

    console.log(
      `${"TOTAL".padEnd(25)} | ${totalBasic} | ${totalEnhanced} | ${totalSaved}`
    );
    console.log("=".repeat(80));

    if (overallSavings.percentSaved > 0) {
      console.log(`🎉 Overall gas savings: ${overallSavings.percentSaved}%`);
      console.log(`💰 Total gas saved: ${overallSavings.saved.toString()}`);
    } else {
      console.log(
        `📊 Enhanced AMM uses ${Math.abs(
          overallSavings.percentSaved
        )}% more gas overall`
      );
      console.log(`ℹ️  This may be due to additional features and precision`);
    }
  }
}

async function runGasComparison() {
  console.log("=== Mathematical AMM Gas Comparison ===\n");

  try {
    // Initialize contracts
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

    const benchmark = new GasBenchmark();
    const deployerAddress = await wallet.getAddress();

    console.log("Setting up test environment...");

    // Ensure we have tokens
    const balanceA = await tokenA.balanceOf(deployerAddress);
    const balanceB = await tokenB.balanceOf(deployerAddress);

    if (
      balanceA.lt(CONFIG.SWAP_AMOUNT.mul(5)) ||
      balanceB.lt(CONFIG.SWAP_AMOUNT.mul(5))
    ) {
      throw new Error(
        "Insufficient token balance. Please run bootstrap first."
      );
    }

    // Ensure approvals
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

    console.log("✅ Environment ready. Starting gas comparison tests...\n");

    // Test 1: Basic Swap Comparison
    console.log("🔄 Testing swap operations...");

    const basicSwapTx = await basicAMM.swap(
      CONFIG.addresses.tokenA,
      CONFIG.SWAP_AMOUNT,
      0,
      deployerAddress
    );

    const enhancedSwapTx = await enhancedAMM.swap(
      CONFIG.addresses.tokenA,
      CONFIG.SWAP_AMOUNT,
      0,
      deployerAddress
    );

    await benchmark.recordTest(
      "Basic Swap",
      basicSwapTx,
      enhancedSwapTx,
      "Standard swap function comparison (both using Solidity logic)"
    );

    // Test 2: Enhanced Swap vs Basic Swap
    console.log("🚀 Testing enhanced swap...");

    const basicSwap2Tx = await basicAMM.swap(
      CONFIG.addresses.tokenB,
      CONFIG.SWAP_AMOUNT,
      0,
      deployerAddress
    );

    const enhancedSwap2Tx = await enhancedAMM.swapEnhanced(
      CONFIG.addresses.tokenB,
      CONFIG.SWAP_AMOUNT,
      0,
      deployerAddress
    );

    await benchmark.recordTest(
      "Enhanced Swap",
      basicSwap2Tx,
      enhancedSwap2Tx,
      "Enhanced swap with Rust mathematical engine vs basic Solidity"
    );

    // Test 3: Liquidity Addition Comparison
    console.log("💧 Testing liquidity addition...");

    const liquidityAmount = parseEther("100");

    const basicLiquidityTx = await basicAMM.addLiquidity(
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      deployerAddress
    );

    const enhancedLiquidityTx = await enhancedAMM.addLiquidityEnhanced(
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      deployerAddress
    );

    await benchmark.recordTest(
      "Add Liquidity",
      basicLiquidityTx,
      enhancedLiquidityTx,
      "Liquidity addition: Babylonian method vs Newton-Raphson square root"
    );

    // Test 4: Compare basic liquidity functions
    console.log("🔄 Testing basic liquidity functions...");

    const basicLiquidity2Tx = await basicAMM.addLiquidity(
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      deployerAddress
    );

    const enhancedBasicLiquidityTx = await enhancedAMM.addLiquidity(
      liquidityAmount,
      liquidityAmount,
      0,
      0,
      deployerAddress
    );

    await benchmark.recordTest(
      "Basic Liquidity Methods",
      basicLiquidity2Tx,
      enhancedBasicLiquidityTx,
      "Both using Babylonian method (should be similar)"
    );

    // Display results
    benchmark.printSummary();

    // Test theoretical calculations
    console.log("\n=== Theoretical Gas Analysis ===");
    console.log("Key differences observed:");
    console.log("• Enhanced swaps use Rust for complex math operations");
    console.log("• Newton-Raphson sqrt in Rust vs Babylonian in Solidity");
    console.log("• Additional precision and features in Enhanced AMM");
    console.log("• Cross-contract calls add some overhead");

    // Show current reserves
    console.log("\n=== Final Pool States ===");
    const [basicReserve0, basicReserve1] = await basicAMM.getReserves();
    const [enhancedReserve0, enhancedReserve1] =
      await enhancedAMM.getReserves();

    console.log("Basic AMM Reserves:");
    console.log(`  Token A: ${formatEther(basicReserve0)}`);
    console.log(`  Token B: ${formatEther(basicReserve1)}`);

    console.log("Enhanced AMM Reserves:");
    console.log(`  Token A: ${formatEther(enhancedReserve0)}`);
    console.log(`  Token B: ${formatEther(enhancedReserve1)}`);
  } catch (error) {
    console.error("❌ Gas comparison failed:", error.message);
    if (error.transaction) {
      console.error("Failed transaction:", error.transaction.hash);
    }
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  runGasComparison();
}

module.exports = { runGasComparison };
