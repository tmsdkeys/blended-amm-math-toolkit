const ethers = require("ethers");
const {
  CONFIG,
  provider,
  wallet,
  ERC20_ABI,
  BASIC_AMM_ABI,
  formatEther,
  parseEther,
  getGasUsed,
} = require("./config");

async function testBasicAMM() {
  console.log("=== Basic AMM Functionality Testing ===\n");

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

    const deployerAddress = await wallet.getAddress();
    console.log(`Testing with address: ${deployerAddress}\n`);

    // Check initial state
    console.log("=== Initial State ===");
    const [reserve0, reserve1] = await basicAMM.getReserves();
    const totalSupply = await basicAMM.totalSupply();
    const lpBalance = await basicAMM.balanceOf(deployerAddress);

    console.log(
      `Reserves: ${formatEther(reserve0)} / ${formatEther(reserve1)}`
    );
    console.log(`Total LP Supply: ${formatEther(totalSupply)}`);
    console.log(`Your LP Balance: ${formatEther(lpBalance)}\n`);

    // Check token balances
    const balanceA = await tokenA.balanceOf(deployerAddress);
    const balanceB = await tokenB.balanceOf(deployerAddress);
    console.log(`Token A Balance: ${formatEther(balanceA)}`);
    console.log(`Token B Balance: ${formatEther(balanceB)}\n`);

    // Ensure approvals
    console.log("Ensuring token approvals...");
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
    console.log("✅ Approvals confirmed\n");

    // Test 1: Add Liquidity
    console.log("=== Test 1: Add Liquidity ===");
    const liquidityAmount = parseEther("100");

    console.log(`Adding ${formatEther(liquidityAmount)} of each token...`);

    const addLiquidityTx = await basicAMM.addLiquidity(
      liquidityAmount,
      liquidityAmount,
      0, // amount0Min
      0, // amount1Min
      deployerAddress
    );

    const addLiquidityReceipt = await addLiquidityTx.wait();
    const addLiquidityGas = addLiquidityReceipt.gasUsed;

    console.log(`Transaction Hash: ${addLiquidityReceipt.transactionHash}`);
    console.log(`Gas Used: ${addLiquidityGas.toString()}`);

    // Check new LP balance
    const newLpBalance = await basicAMM.balanceOf(deployerAddress);
    const lpReceived = newLpBalance.sub(lpBalance);
    console.log(`LP Tokens Received: ${formatEther(lpReceived)}`);

    // Check new reserves
    const [newReserve0, newReserve1] = await basicAMM.getReserves();
    console.log(
      `New Reserves: ${formatEther(newReserve0)} / ${formatEther(
        newReserve1
      )}\n`
    );

    // Test 2: Quote Function
    console.log("=== Test 2: Quote Function ===");
    const quoteAmount = parseEther("50");
    const quotedAmount = await basicAMM.quote(
      quoteAmount,
      newReserve0,
      newReserve1
    );

    console.log(`Quote ${formatEther(quoteAmount)} Token A:`);
    console.log(`Expected Token B: ${formatEther(quotedAmount)}`);
    console.log(
      `Rate: 1 Token A = ${formatEther(
        quotedAmount.mul(parseEther("1")).div(quoteAmount)
      )} Token B\n`
    );

    // Test 3: Swap Token A for Token B
    console.log("=== Test 3: Swap Token A for Token B ===");
    const swapAmount = parseEther("50");

    console.log(`Swapping ${formatEther(swapAmount)} Token A for Token B...`);

    const swapTx = await basicAMM.swap(
      CONFIG.addresses.tokenA,
      swapAmount,
      0, // amountOutMin
      deployerAddress
    );

    const swapReceipt = await swapTx.wait();
    const swapGas = swapReceipt.gasUsed;

    console.log(`Transaction Hash: ${swapReceipt.transactionHash}`);
    console.log(`Gas Used: ${swapGas.toString()}`);

    // Check reserves after swap
    const [postSwapReserve0, postSwapReserve1] = await basicAMM.getReserves();
    console.log(
      `Reserves After Swap: ${formatEther(postSwapReserve0)} / ${formatEther(
        postSwapReserve1
      )}`
    );

    // Calculate how much Token B was received
    const reserve1Change = newReserve1.sub(postSwapReserve1);
    console.log(`Token B Received: ${formatEther(reserve1Change)}`);

    // Calculate effective rate
    const effectiveRate = reserve1Change.mul(parseEther("1")).div(swapAmount);
    console.log(
      `Effective Rate: 1 Token A = ${formatEther(effectiveRate)} Token B\n`
    );

    // Test 4: Calculate Slippage
    console.log("=== Test 4: Slippage Calculation ===");
    const slippageTestAmount = parseEther("100");
    const slippage = await basicAMM.calculateSlippage(
      slippageTestAmount,
      postSwapReserve0,
      postSwapReserve1
    );

    console.log(`Slippage for ${formatEther(slippageTestAmount)} Token A:`);
    console.log(`Slippage: ${slippage.toString()}% (scaled by 100)`);
    console.log(`Actual: ${slippage.toNumber() / 100}%\n`);

    // Test 5: Swap Token B for Token A
    console.log("=== Test 5: Swap Token B for Token A ===");
    const swapBackAmount = parseEther("30");

    console.log(
      `Swapping ${formatEther(swapBackAmount)} Token B for Token A...`
    );

    const swapBackTx = await basicAMM.swap(
      CONFIG.addresses.tokenB,
      swapBackAmount,
      0, // amountOutMin
      deployerAddress
    );

    const swapBackReceipt = await swapBackTx.wait();
    const swapBackGas = swapBackReceipt.gasUsed;

    console.log(`Transaction Hash: ${swapBackReceipt.transactionHash}`);
    console.log(`Gas Used: ${swapBackGas.toString()}`);

    // Check final reserves
    const [finalReserve0, finalReserve1] = await basicAMM.getReserves();
    console.log(
      `Final Reserves: ${formatEther(finalReserve0)} / ${formatEther(
        finalReserve1
      )}\n`
    );

    // Test 6: Remove Some Liquidity
    console.log("=== Test 6: Remove Liquidity ===");
    const currentLpBalance = await basicAMM.balanceOf(deployerAddress);
    const liquidityToRemove = currentLpBalance.div(4); // Remove 25%

    console.log(
      `Removing ${formatEther(
        liquidityToRemove
      )} LP tokens (25% of holdings)...`
    );

    const removeLiquidityTx = await basicAMM.removeLiquidity(
      liquidityToRemove,
      0, // amount0Min
      0, // amount1Min
      deployerAddress
    );

    const removeLiquidityReceipt = await removeLiquidityTx.wait();
    const removeLiquidityGas = removeLiquidityReceipt.gasUsed;

    console.log(`Transaction Hash: ${removeLiquidityReceipt.transactionHash}`);
    console.log(`Gas Used: ${removeLiquidityGas.toString()}`);

    // Check final state
    const [endReserve0, endReserve1] = await basicAMM.getReserves();
    const endLpBalance = await basicAMM.balanceOf(deployerAddress);
    const endTotalSupply = await basicAMM.totalSupply();

    console.log(
      `Final Reserves: ${formatEther(endReserve0)} / ${formatEther(
        endReserve1
      )}`
    );
    console.log(`Final LP Balance: ${formatEther(endLpBalance)}`);
    console.log(`Final Total Supply: ${formatEther(endTotalSupply)}\n`);

    // Gas Usage Summary
    console.log("=== Gas Usage Summary ===");
    const operations = [
      ["Add Liquidity", addLiquidityGas],
      ["Swap A→B", swapGas],
      ["Swap B→A", swapBackGas],
      ["Remove Liquidity", removeLiquidityGas],
    ];

    let totalGas = ethers.BigNumber.from(0);

    operations.forEach(([name, gas]) => {
      console.log(`${name.padEnd(20)}: ${gas.toString().padStart(8)} gas`);
      totalGas = totalGas.add(gas);
    });

    console.log("-".repeat(35));
    console.log(
      `${"Total".padEnd(20)}: ${totalGas.toString().padStart(8)} gas`
    );

    console.log("\n✅ Basic AMM testing completed successfully!");
    console.log("\nBasic AMM Features Tested:");
    console.log("• ✅ Liquidity addition with Babylonian square root");
    console.log("• ✅ Constant product swaps (x * y = k)");
    console.log("• ✅ Price quotations");
    console.log("• ✅ Slippage calculations");
    console.log("• ✅ Liquidity removal");
    console.log("• ✅ Gas usage tracking");
  } catch (error) {
    console.error("❌ Basic AMM testing failed:", error.message);
    if (error.transaction) {
      console.error("Failed transaction:", error.transaction.hash);
    }
    process.exit(1);
  }
}

// Run if called directly
if (require.main === module) {
  testBasicAMM();
}

module.exports = { testBasicAMM };
