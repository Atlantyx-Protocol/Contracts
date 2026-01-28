ifneq (,$(wildcard .env))
include .env
export
endif

USDC_SCRIPT := script/DeployUSDC.s.sol:USDCScript
HTLC_SCRIPT := script/DeployHTLCErc20.s.sol:DeployHTLCErc20
HTLC_NEW_SCRIPT := script/NewHTLCErc20.s.sol:NewHTLCErc20
HTLC_WITHDRAW_SCRIPT := script/WithdrawHTLCErc20.s.sol:WithdrawHTLCErc20
HTLC_REFUND_SCRIPT := script/RefundHTLCErc20.s.sol:RefundHTLCErc20

.PHONY: deploy-all deploy-sepolia deploy-arbitrum-sepolia deploy-base-sepolia mint-one check-key
.PHONY: deploy-htlc deploy-htlc-sepolia deploy-htlc-arbitrum-sepolia deploy-htlc-base-sepolia
.PHONY: htlc-new htlc-withdraw htlc-refund

define deploy_usdc
	@if [ -z "$(2)" ]; then \
		echo "Skipping $(1) (missing RPC URL)"; \
	else \
		echo "Deploying USDC to $(1)"; \
		forge script $(USDC_SCRIPT) --rpc-url $(2) --broadcast --private-key $(PRIVATE_KEY) $(3); \
	fi
endef

check-key:
	@if [ -z "$(PRIVATE_KEY)" ]; then \
		echo "PRIVATE_KEY is required"; \
		exit 1; \
	fi

deploy-all: check-key deploy-sepolia deploy-arbitrum-sepolia deploy-base-sepolia 

deploy-sepolia: check-key
	$(call deploy_usdc,Ethereum Sepolia,$(SEPOLIA_RPC_URL))

deploy-arbitrum-sepolia: check-key
	$(call deploy_usdc,Arbitrum Sepolia,$(ARBITRUM_SEPOLIA_RPC_URL))

deploy-base-sepolia: check-key
	$(call deploy_usdc,Base Sepolia,$(BASE_SEPOLIA_RPC_URL))

# deploy-optimism-sepolia: check-key
# 	$(call deploy,Optimism Sepolia,$(OPTIMISM_SEPOLIA_RPC_URL))

# deploy-zksync-sepolia: check-key
# 	$(call deploy,zkSync Sepolia,$(ZKSYNC_SEPOLIA_RPC_URL),--zksync)

deploy-htlc: check-key deploy-htlc-sepolia deploy-htlc-arbitrum-sepolia deploy-htlc-base-sepolia

define deploy_htlc
	@if [ -z "$(2)" ]; then \
		echo "Skipping $(1) HTLC (missing RPC URL)"; \
	else \
		echo "Deploying HTLC to $(1)"; \
		forge script $(HTLC_SCRIPT) --rpc-url $(2) --broadcast --private-key $(PRIVATE_KEY) $(3); \
	fi
endef

deploy-htlc-sepolia: check-key
	$(call deploy_htlc,Ethereum Sepolia,$(SEPOLIA_RPC_URL))

deploy-htlc-arbitrum-sepolia: check-key
	$(call deploy_htlc,Arbitrum Sepolia,$(ARBITRUM_SEPOLIA_RPC_URL))

deploy-htlc-base-sepolia: check-key
	$(call deploy_htlc,Base Sepolia,$(BASE_SEPOLIA_RPC_URL))

htlc-new: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(RECEIVER)" ] || [ -z "$(HASHLOCK)" ] || [ -z "$(TIMELOCK)" ] || [ -z "$(TOKEN)" ] || [ -z "$(AMOUNT)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, RECEIVER, HASHLOCK, TIMELOCK, TOKEN, AMOUNT, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) RECEIVER=$(RECEIVER) HASHLOCK=$(HASHLOCK) TIMELOCK=$(TIMELOCK) TOKEN=$(TOKEN) AMOUNT=$(AMOUNT) forge script $(HTLC_NEW_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-withdraw: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(ID)" ] || [ -z "$(PREIMAGE)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, ID, PREIMAGE, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) ID=$(ID) PREIMAGE=$(PREIMAGE) forge script $(HTLC_WITHDRAW_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-refund: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(ID)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, ID, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) ID=$(ID) forge script $(HTLC_REFUND_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

mint-one: check-key
	@if [ -z "$(USDC)" ] || [ -z "$(RECIPIENT)" ] || [ -z "$(AMOUNT)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "USDC, RECIPIENT, AMOUNT, and RPC_URL are required"; \
		exit 1; \
	fi
	forge script script/MintSingleUSDC.s.sol:MintSingleUSDC --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)
