# Deployment Guide

This guide explains how to deploy the Mathematical AMM Toolkit to different Fluent networks.

## 🚀 Quick Deployment

### Prerequisites

1. **Environment Setup**
   ```bash
   # Set your private key
   export PRIVATE_KEY=your_private_key_here
   
   # Or create a .env file
   echo "PRIVATE_KEY=your_private_key_here" > .env
   ```

2. **Token Setup (Optional)**
   ```bash
   # If you want to use existing tokens, add them to the deployment file:
   echo '{
     "tokenA": "0xYourTokenAAddress",
     "tokenB": "0xYourTokenBAddress"
   }' > deployments/testnet.json
   
   # Or leave empty to deploy new mock tokens
   ```

3. **Build Contracts**
   ```bash
   make build
   ```

### Deploy to Testnet (Default)

```bash
# Using Makefile (recommended)
make deploy

# Or using forge directly
forge script script/Deploy.s.sol --profile testnet --broadcast
```

### Deploy to Devnet

```bash
# Using Makefile (recommended)
make deploy-devnet

# Or using forge directly
forge script script/Deploy.s.sol --profile devnet --broadcast
```

## 🔧 Network Configuration

The project automatically detects networks using chain IDs:

- **Testnet**: Chain ID `20994` → `./deployments/testnet.json`
- **Devnet**: Chain ID `20993` → `./deployments/devnet.json`

The deployment scripts automatically detect which network they're running on and use the appropriate deployment file. All logs show the chain ID directly for clarity.

### Token Deployment Logic

The deployment script intelligently handles tokens:

1. **Existing Tokens**: If `tokenA` and `tokenB` addresses are provided in the deployment file, they will be used
2. **Mock Tokens**: If no addresses are provided or they are zero addresses, new MockERC20 tokens will be deployed
3. **Hybrid**: You can mix existing and new tokens (e.g., use existing Token A, deploy new Token B)

**Example deployment file with existing tokens:**
```json
{
  "tokenA": "0x1234567890123456789012345678901234567890",
  "tokenB": "0x0987654321098765432109876543210987654321"
}
```

**Example deployment file for new tokens:**
```json
{
  "tokenA": "0x0000000000000000000000000000000000000000",
  "tokenB": "0x0000000000000000000000000000000000000000"
}
```

### Foundry Profiles

```toml
# foundry.toml
[profile.testnet]
rpc_url = "https://rpc.testnet.fluent.xyz"
deployment_file = "./deployments/testnet.json"

[profile.devnet]
rpc_url = "https://rpc.devnet.fluent.xyz"
deployment_file = "./deployments/devnet.json"
```

### RPC Endpoints

- **Testnet**: `https://rpc.testnet.fluent.xyz`
- **Devnet**: `https://rpc.devnet.fluent.xyz`

## 📁 Deployment Files

Deployment addresses are automatically saved to network-specific files:

- **Testnet**: `./deployments/testnet.json`
- **Devnet**: `./deployments/devnet.json`

### File Structure

```json
{
  "tokenA": "0x...",
  "tokenB": "0x...",
  "mathEngine": "0x...",
  "basicAMM": "0x...",
  "blendedAMM": "0x..."
}
```

## 🚀 Complete Deployment Workflow

### 1. Deploy Contracts

```bash
# Deploy to testnet
make deploy

# Deploy to devnet
make deploy-devnet
```

### 2. Bootstrap with Liquidity

```bash
# Bootstrap on testnet
make bootstrap

# Bootstrap on devnet
make bootstrap-devnet
```

### 3. Verify Deployment

```bash
# Check deployment files
cat deployments/testnet.json
cat deployments/devnet.json
```

## 🔍 Manual Deployment

If you prefer to run commands manually:

```bash
# Deploy using specific profile
forge script script/Deploy.s.sol --profile testnet --broadcast

# Deploy using specific RPC
forge script script/Deploy.s.sol --rpc-url https://rpc.testnet.fluent.xyz --broadcast

# Bootstrap after deployment
forge script script/Bootstrap.s.sol --profile testnet --broadcast
```

## 🧪 Testing After Deployment

```bash
# Run all tests
make test

# Run gas benchmarks
make test-gas

# Create gas snapshot
make snapshot
```

## 🔧 Troubleshooting

### Common Issues

1. **Private Key Not Set**
   ```bash
   export PRIVATE_KEY=your_private_key_here
   ```

2. **Wrong Network Profile**
   ```bash
   # Check current profile
   forge config --profile testnet
   
   # Use specific profile
   forge script script/Deploy.s.sol --profile testnet --broadcast
   ```

3. **Insufficient Balance**
   - Ensure your account has enough FLU tokens for gas
   - Check network faucet if needed

### Verification

```bash
# Verify deployment on explorer
make verify-rust

# Check contract state
forge console --profile testnet
```

## 📊 Network Status

- **Testnet**: Production-ready, stable
- **Devnet**: Development/testing, may be unstable

## 🔗 Useful Links

- [Fluent Testnet Explorer](https://explorer.testnet.fluent.xyz)
- [Fluent Devnet Explorer](https://explorer.devnet.fluent.xyz)
- [Fluent Documentation](https://docs.fluent.xyz)
