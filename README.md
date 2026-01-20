## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy USDC

Deploy the mock USDC (6 decimals, 1e9 initial supply) to a single network:

```shell
PRIVATE_KEY=<pk> forge script script/DeployUSDC.s.sol:USDCScript --rpc-url <rpc_url> --broadcast
```

Deploy to all Sepolia networks at once (Sepolia, Arbitrum/Optimism/Base/zkSync Sepolia):

Create a `.env` file with your configuration:

```shell
PRIVATE_KEY=0x...
SEPOLIA_RPC_URL=https://...
ARBITRUM_SEPOLIA_RPC_URL=https://...
OPTIMISM_SEPOLIA_RPC_URL=https://...
BASE_SEPOLIA_RPC_URL=https://...
ZKSYNC_SEPOLIA_RPC_URL=https://...
```

Then run:

```shell
make deploy-all
```

The Makefile automatically loads variables from `.env` if it exists.

### Mint USDC (single address)

Mint to one address (amount in raw units; USDC uses 6 decimals) via Makefile with `.env`:

Create a `.env` file with your configuration:

```shell
USDC=0xYourToken
RECIPIENT=0xRecipient
AMOUNT=1000000        # 1 USDC (6 decimals)
RPC_URL=https://...
PRIVATE_KEY=0x...
```

Then run:

```shell
make mint-one
```

The Makefile automatically loads variables from `.env` if it exists.

### Mint USDC (multiple addresses)

Mint the same amount to multiple addresses (comma-separated recipients):

```shell
USDC=<token_address> RECIPIENTS=<addr1,addr2> AMOUNT=<amount> \
forge script script/MintUSDC.s.sol:MintUSDCScript --rpc-url <rpc_url> --broadcast --private-key <pk>
```
