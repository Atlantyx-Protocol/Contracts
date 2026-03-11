ifneq (,$(wildcard .env))
include .env
export
endif

USDC_SCRIPT := script/DeployUSDC.s.sol:USDCScript
HTLC_SCRIPT := script/DeployHTLCErc20.s.sol:DeployHTLCErc20
HTLC_NEW_SCRIPT := script/NewHTLCErc20.s.sol:NewHTLCErc20
HTLC_WITHDRAW_SCRIPT := script/WithdrawHTLCErc20.s.sol:WithdrawHTLCErc20
HTLC_REFUND_SCRIPT := script/RefundHTLCErc20.s.sol:RefundHTLCErc20
HTLC_ADD_ADMIN_SCRIPT := script/AddAdminHTLCErc20.s.sol:AddAdminHTLCErc20
HTLC_REMOVE_ADMIN_SCRIPT := script/RemoveAdminHTLCErc20.s.sol:RemoveAdminHTLCErc20

.PHONY: deploy-all deploy-sepolia deploy-arbitrum-sepolia deploy-base-sepolia check-key
.PHONY: deploy-htlc deploy-htlc-sepolia deploy-htlc-arbitrum-sepolia deploy-htlc-base-sepolia
.PHONY: htlc-new htlc-new-sepolia htlc-new-arbitrum-sepolia htlc-new-base-sepolia
.PHONY: htlc-withdraw htlc-withdraw-sepolia htlc-withdraw-arbitrum-sepolia htlc-withdraw-base-sepolia
.PHONY: htlc-refund htlc-refund-sepolia htlc-refund-arbitrum-sepolia htlc-refund-base-sepolia
.PHONY: htlc-add-admin htlc-add-admin-all htlc-add-admin-sepolia htlc-add-admin-arbitrum-sepolia htlc-add-admin-base-sepolia
.PHONY: htlc-remove-admin htlc-remove-admin-sepolia htlc-remove-admin-arbitrum-sepolia htlc-remove-admin-base-sepolia
.PHONY: mint-one mint-sepolia mint-arbitrum-sepolia mint-base-sepolia

define deploy_usdc
	@if [ -z "$(2)" ]; then \
		echo "Skipping $(1) (missing RPC URL)"; \
	else \
		echo "Deploying USDC to $(1)"; \
		forge script $(USDC_SCRIPT) --rpc-url $(2) --broadcast --private-key $(PRIVATE_KEY) --verify --etherscan-api-key $(ETHERSCAN_API) $(3); \
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
		forge script $(HTLC_SCRIPT) --rpc-url $(2) --broadcast --private-key $(PRIVATE_KEY) --verify --etherscan-api-key $(ETHERSCAN_API) $(3); \
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

htlc-new-sepolia: check-key
	@if [ -z "$(RECEIVER)" ] || [ -z "$(HASHLOCK)" ] || [ -z "$(TIMELOCK)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "RECEIVER, HASHLOCK, TIMELOCK, and AMOUNT are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_SEPOLIA) RECEIVER=$(RECEIVER) HASHLOCK=$(HASHLOCK) TIMELOCK=$(TIMELOCK) TOKEN=$(USDC_ADDRESS_SEPOLIA) AMOUNT=$(AMOUNT) forge script $(HTLC_NEW_SCRIPT) --rpc-url $(SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-new-arbitrum-sepolia: check-key
	@if [ -z "$(RECEIVER)" ] || [ -z "$(HASHLOCK)" ] || [ -z "$(TIMELOCK)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "RECEIVER, HASHLOCK, TIMELOCK, and AMOUNT are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_ARBITRUM_SEPOLIA) RECEIVER=$(RECEIVER) HASHLOCK=$(HASHLOCK) TIMELOCK=$(TIMELOCK) TOKEN=$(USDC_ADDRESS_ARBITRIM_SEPOLOA) AMOUNT=$(AMOUNT) forge script $(HTLC_NEW_SCRIPT) --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-new-base-sepolia: check-key
	@if [ -z "$(RECEIVER)" ] || [ -z "$(HASHLOCK)" ] || [ -z "$(TIMELOCK)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "RECEIVER, HASHLOCK, TIMELOCK, and AMOUNT are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_BASE_SEPOLIA) RECEIVER=$(RECEIVER) HASHLOCK=$(HASHLOCK) TIMELOCK=$(TIMELOCK) TOKEN=$(USDC_ADDRESS_BASE_SEPOLOA) AMOUNT=$(AMOUNT) forge script $(HTLC_NEW_SCRIPT) --rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-withdraw: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(ORDER_ID)" ] || [ -z "$(FILL_ID)" ] || [ -z "$(PREIMAGE)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, ORDER_ID, FILL_ID, PREIMAGE, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) ORDER_ID=$(ORDER_ID) FILL_ID=$(FILL_ID) PREIMAGE=$(PREIMAGE) forge script $(HTLC_WITHDRAW_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-withdraw-sepolia: check-key
	@if [ -z "$(ORDER_ID)" ] || [ -z "$(FILL_ID)" ] || [ -z "$(PREIMAGE)" ]; then \
		echo "ORDER_ID, FILL_ID, and PREIMAGE are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_SEPOLIA) ORDER_ID=$(ORDER_ID) FILL_ID=$(FILL_ID) PREIMAGE=$(PREIMAGE) forge script $(HTLC_WITHDRAW_SCRIPT) --rpc-url $(SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-withdraw-arbitrum-sepolia: check-key
	@if [ -z "$(ORDER_ID)" ] || [ -z "$(FILL_ID)" ] || [ -z "$(PREIMAGE)" ]; then \
		echo "ORDER_ID, FILL_ID, and PREIMAGE are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_ARBITRUM_SEPOLIA) ORDER_ID=$(ORDER_ID) FILL_ID=$(FILL_ID) PREIMAGE=$(PREIMAGE) forge script $(HTLC_WITHDRAW_SCRIPT) --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-withdraw-base-sepolia: check-key
	@if [ -z "$(ORDER_ID)" ] || [ -z "$(FILL_ID)" ] || [ -z "$(PREIMAGE)" ]; then \
		echo "ORDER_ID, FILL_ID, and PREIMAGE are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_BASE_SEPOLIA) ORDER_ID=$(ORDER_ID) FILL_ID=$(FILL_ID) PREIMAGE=$(PREIMAGE) forge script $(HTLC_WITHDRAW_SCRIPT) --rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-refund: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(ORDER_ID)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, ORDER_ID, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) ORDER_ID=$(ORDER_ID) forge script $(HTLC_REFUND_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-refund-sepolia: check-key
	@if [ -z "$(ORDER_ID)" ]; then \
		echo "ORDER_ID is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_SEPOLIA) ORDER_ID=$(ORDER_ID) forge script $(HTLC_REFUND_SCRIPT) --rpc-url $(SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-refund-arbitrum-sepolia: check-key
	@if [ -z "$(ORDER_ID)" ]; then \
		echo "ORDER_ID is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_ARBITRUM_SEPOLIA) ORDER_ID=$(ORDER_ID) forge script $(HTLC_REFUND_SCRIPT) --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-refund-base-sepolia: check-key
	@if [ -z "$(ORDER_ID)" ]; then \
		echo "ORDER_ID is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_BASE_SEPOLIA) ORDER_ID=$(ORDER_ID) forge script $(HTLC_REFUND_SCRIPT) --rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-add-admin: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(ADMIN)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, ADMIN, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) ADMIN=$(ADMIN) forge script $(HTLC_ADD_ADMIN_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-add-admin-sepolia: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_SEPOLIA) ADMIN=$(ADMIN) forge script $(HTLC_ADD_ADMIN_SCRIPT) --rpc-url $(SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-add-admin-arbitrum-sepolia: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_ARBITRUM_SEPOLIA) ADMIN=$(ADMIN) forge script $(HTLC_ADD_ADMIN_SCRIPT) --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-add-admin-base-sepolia: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_BASE_SEPOLIA) ADMIN=$(ADMIN) forge script $(HTLC_ADD_ADMIN_SCRIPT) --rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-add-admin-all: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	$(MAKE) htlc-add-admin-sepolia ADMIN=$(ADMIN)
	$(MAKE) htlc-add-admin-arbitrum-sepolia ADMIN=$(ADMIN)
	$(MAKE) htlc-add-admin-base-sepolia ADMIN=$(ADMIN)

htlc-remove-admin: check-key
	@if [ -z "$(HTLC)" ] || [ -z "$(ADMIN)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "HTLC, ADMIN, and RPC_URL are required"; \
		exit 1; \
	fi
	HTLC=$(HTLC) ADMIN=$(ADMIN) forge script $(HTLC_REMOVE_ADMIN_SCRIPT) --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-remove-admin-sepolia: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_SEPOLIA) ADMIN=$(ADMIN) forge script $(HTLC_REMOVE_ADMIN_SCRIPT) --rpc-url $(SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-remove-admin-arbitrum-sepolia: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_ARBITRUM_SEPOLIA) ADMIN=$(ADMIN) forge script $(HTLC_REMOVE_ADMIN_SCRIPT) --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

htlc-remove-admin-base-sepolia: check-key
	@if [ -z "$(ADMIN)" ]; then \
		echo "ADMIN is required"; \
		exit 1; \
	fi
	HTLC=$(HTLC_ADDRESS_BASE_SEPOLIA) ADMIN=$(ADMIN) forge script $(HTLC_REMOVE_ADMIN_SCRIPT) --rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

mint-one: check-key
	@if [ -z "$(USDC)" ] || [ -z "$(RECIPIENTS)" ] || [ -z "$(AMOUNT)" ] || [ -z "$(RPC_URL)" ]; then \
		echo "USDC, RECIPIENTS, AMOUNT, and RPC_URL are required"; \
		exit 1; \
	fi
	USDC=$(USDC) RECIPIENTS=$(RECIPIENTS) AMOUNT=$(AMOUNT) forge script script/MintUSDC.s.sol:MintUSDCScript --rpc-url $(RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

mint-sepolia: check-key
	@if [ -z "$(RECIPIENTS)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "RECIPIENTS and AMOUNT are required"; \
		exit 1; \
	fi
	USDC=$(USDC_ADDRESS_SEPOLIA) RECIPIENTS=$(RECIPIENTS) AMOUNT=$(AMOUNT) forge script script/MintUSDC.s.sol:MintUSDCScript --rpc-url $(SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

mint-arbitrum-sepolia: check-key
	@if [ -z "$(RECIPIENTS)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "RECIPIENTS and AMOUNT are required"; \
		exit 1; \
	fi
	USDC=$(USDC_ADDRESS_ARBITRIM_SEPOLOA) RECIPIENTS=$(RECIPIENTS) AMOUNT=$(AMOUNT) forge script script/MintUSDC.s.sol:MintUSDCScript --rpc-url $(ARBITRUM_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)

mint-base-sepolia: check-key
	@if [ -z "$(RECIPIENTS)" ] || [ -z "$(AMOUNT)" ]; then \
		echo "RECIPIENTS and AMOUNT are required"; \
		exit 1; \
	fi
	USDC=$(USDC_ADDRESS_BASE_SEPOLOA) RECIPIENTS=$(RECIPIENTS) AMOUNT=$(AMOUNT) forge script script/MintUSDC.s.sol:MintUSDCScript --rpc-url $(BASE_SEPOLIA_RPC_URL) --broadcast --private-key $(PRIVATE_KEY)
