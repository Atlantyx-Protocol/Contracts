ifneq (,$(wildcard .env))
include .env
export
endif

SCRIPT := script/DeployUSDC.s.sol:USDCScript

.PHONY: deploy-all deploy-sepolia deploy-arbitrum-sepolia deploy-base-sepolia mint-one check-key

define deploy
	@if [ -z "$(2)" ]; then \
		echo "Skipping $(1) (missing RPC URL)"; \
	else \
		echo "Deploying USDC to $(1)"; \
		forge script $(SCRIPT) --rpc-url $(2) --broadcast --private-key $(PRIVATE_KEY) $(3); \
	fi
endef

check-key:
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "PRIVATE_KEY is required"; \
		exit 1; \
	fi

deploy-all: check-key deploy-sepolia deploy-arbitrum-sepolia deploy-base-sepolia 

deploy-sepolia: check-key
	$(call deploy,Ethereum Sepolia,$(SEPOLIA_RPC_URL))

deploy-arbitrum-sepolia: check-key
	$(call deploy,Arbitrum Sepolia,$(ARBITRUM_SEPOLIA_RPC_URL))

deploy-base-sepolia: check-key
	$(call deploy,Base Sepolia,$(BASE_SEPOLIA_RPC_URL))

# deploy-optimism-sepolia: check-key
# 	$(call deploy,Optimism Sepolia,$(OPTIMISM_SEPOLIA_RPC_URL))

# deploy-zksync-sepolia: check-key
# 	$(call deploy,zkSync Sepolia,$(ZKSYNC_SEPOLIA_RPC_URL),--zksync)

mint-one: check-key
	@if [ -z "$(USDC)" ] || [ -z "$(RECIPIENT)" ] || [ -z "$(AMOUNT)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "USDC, RECIPIENT, AMOUNT, and RPC_URL are required"; \
		exit 1; \
	fi
	forge script script/MintSingleUSDC.s.sol:MintSingleUSDC --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)
