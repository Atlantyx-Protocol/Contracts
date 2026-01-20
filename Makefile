SCRIPT := script/DeployUSDC.s.sol:USDCScript

.PHONY: deploy-all deploy-sepolia deploy-arbitrum-sepolia deploy-optimism-sepolia deploy-base-sepolia deploy-zksync-sepolia check-key

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

deploy-all: check-key deploy-sepolia deploy-arbitrum-sepolia deploy-optimism-sepolia deploy-base-sepolia deploy-zksync-sepolia

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
