# Mathematical AMM Toolkit - Makefile
# Convenience commands using gblend/forge

# Colors for output
RED := \033[0;31m
GREEN := \033[0;32m
BLUE := \033[0;34m
NC := \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "Mathematical AMM Toolkit - Available Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: setup
setup: ## Initialize and update submodules
	@echo "$(BLUE)Setting up submodules...$(NC)"
	git submodule update --init --recursive

.PHONY: clean
clean: ## Clean build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	gblend clean

.PHONY: build
build: ## Build all contracts (Rust and Solidity)
	@echo "$(BLUE)Building all contracts with gblend...$(NC)"
	gblend build
	@echo "$(GREEN)✓ All contracts built$(NC)"
	@echo "$(GREEN)✓ WASM at: out/MathematicalEngine/MathematicalEngine.wasm$(NC)"
	@echo "$(GREEN)✓ Interface at: out/MathematicalEngine.wasm/interface.sol$(NC)"

.PHONY: build-solidity
build-solidity: ## Build only Solidity contracts
	@echo "$(BLUE)Building Solidity contracts...$(NC)"
	forge build
	@echo "$(GREEN)✓ Solidity contracts built$(NC)"

.PHONY: deploy-rust
deploy-rust: build ## Deploy the Rust mathematical engine standalone
	@echo "$(BLUE)Deploying Rust mathematical engine...$(NC)"
	gblend create MathematicalEngine.wasm \
		--rpc-url fluent-testnet \
		--private-key $PRIVATE_KEY \
		--broadcast
	@echo "$(GREEN)✓ Math Engine deployed$(NC)"

.PHONY: deploy-amm
deploy-amm: build ## Deploy AMM contracts standalone
	@echo "$(BLUE)Deploying Basic AMM...$(NC)"
	gblend create src/BasicAMM.sol:BasicAMM \
		--rpc-url fluent-testnet \
		--private-key $PRIVATE_KEY \
		--broadcast \
		--constructor-args $TOKEN_A $TOKEN_B "Basic AMM LP Token" "BAMM-LP"
	@echo "$(GREEN)✓ Basic AMM deployed$(NC)"
	
	@echo "$(BLUE)Deploying Enhanced AMM...$(NC)"
	gblend create src/BlendedAMM.sol:BlendedAMM \
		--rpc-url fluent-testnet \
		--private-key $PRIVATE_KEY \
		--broadcast \
		--constructor-args \
			$TOKEN_A \
			$TOKEN_B \
			$MATH_ENGINE \
			"Enhanced AMM LP Token" \
			"EAMM-LP"
	@echo "$(GREEN)✓ Enhanced AMM deployed$(NC)"

.PHONY: deploy
deploy: build ## Deploy all contracts using the deployment script
	@echo "$(BLUE)Deploying all contracts via script...$(NC)"
	gblend script script/Deploy.s.sol:Deploy \
		--rpc-url fluent-testnet \
		--private-key $PRIVATE_KEY \
		--broadcast \
		-vvv
	@echo "$(GREEN)✓ All contracts deployed$(NC)"

.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running tests...$(NC)"
	forge test -vv

.PHONY: test-gas
test-gas: ## Run gas benchmark tests
	@echo "$(BLUE)Running gas benchmarks...$(NC)"
	forge test --match-contract GasBenchmark --gas-report -vvv

.PHONY: snapshot
snapshot: ## Create gas snapshot
	@echo "$(BLUE)Creating gas snapshot...$(NC)"
	forge snapshot --match-contract GasBenchmark
	@echo "$(GREEN)✓ Snapshot saved to .gas-snapshot$(NC)"

.PHONY: anvil
anvil: ## Start local Anvil testnet
	@echo "$(BLUE)Starting Anvil...$(NC)"
	anvil --host 0.0.0.0 --port 8545

.PHONY: verify-rust
verify-rust: ## Verify the Rust contract on explorer
	@echo "$(BLUE)Verifying Rust contract...$(NC)"
	@echo "Please provide the deployed address:"
	@read -p "Contract address: " ADDRESS; \
	gblend verify-contract $$ADDRESS MathematicalEngine.wasm \
		--verifier blockscout \
		--verifier-url https://blockscout.dev.fluentlabs.xyz \
		--wasm

.PHONY: benchmark
benchmark: deploy test-gas snapshot ## Run complete benchmark suite
	@echo "$(GREEN)✓ Benchmark complete!$(NC)"
	@echo "Check the gas report above for detailed analysis"

.PHONY: console
console: ## Open Forge console
	forge console

# Convenience aliases
.PHONY: b
b: build

.PHONY: d
d: deploy

.PHONY: t
t: test