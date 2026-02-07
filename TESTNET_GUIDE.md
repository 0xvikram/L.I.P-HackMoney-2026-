# Testnet Deployment Guide

## Prerequisites

1. **Find Uniswap v4 PoolManager address** for your testnet
   - Check: https://docs.uniswap.org/contracts/v4/deployments
   - Or Uniswap Discord/GitHub for latest addresses

2. **Get testnet ETH** from faucet
   - Sepolia: https://sepoliafaucet.com/
   - Base Sepolia: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet

## Configuration

### Option A: Edit the script directly

Open `script/TestnetDemo.s.sol` and update:

```solidity
address constant POOL_MANAGER = 0x000000000004444c5dc75cB358380D2e3dE08A90;
bool constant DEPLOY_HOOK = false;  // Set true to attempt hook deployment
bool constant SKIP_EXECUTION = true; // Set false to attempt execution
```

### Option B: Use environment variables (recommended)

Create `.env` file:

```bash
POOL_MANAGER_ADDRESS=0x...
TESTNET_RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
PRIVATE_KEY=0x...
```

## Deployment

### 1. Quick Test (No Hook)

Deploy just the core contracts:

```bash
forge script script/TestnetDemo.s.sol \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast
```

### 2. With Hook (Advanced)

⚠️ **Warning**: Hook deployment requires salt mining and may take time or fail.

Edit script:

```solidity
bool constant DEPLOY_HOOK = true;
```

Then run:

```bash
forge script script/TestnetDemo.s.sol \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY> \
  --broadcast \
  --slow  # Helps with salt mining
```

### 3. Verify Contracts

```bash
forge verify-contract \
  --rpc-url <RPC_URL> \
  --etherscan-api-key <API_KEY> \
  --chain-id <CHAIN_ID> \
  <CONTRACT_ADDRESS> \
  src/LIP/IntentManager.sol:IntentManager
```

## Testing on Testnet

### Create an Intent

```bash
cast send <IntentManager_Address> \
  "createIntent((address,address,uint24,int24,address),int24,int24,uint128,uint128)" \
  "(<poolKey_params>)" \
  -100 \
  100 \
  1000000000000000000000 \
  250000000000000000000 \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY>
```

### Query Intent

```bash
cast call <IntentManager_Address> \
  "getIntent(uint256)" \
  1 \
  --rpc-url <RPC_URL>
```

### Execute Chunk (requires tokens and approvals)

```bash
cast send <ChunkExecutor_Address> \
  "executeChunk(uint256,uint128)" \
  1 \
  250000000000000000000 \
  --rpc-url <RPC_URL> \
  --private-key <PRIVATE_KEY>
```

## Known Testnets with v4

As of February 2026, check for latest deployments:

### Sepolia

- PoolManager: (Check docs)
- Faucet: https://sepoliafaucet.com/

### Base Sepolia

- PoolManager: (Check docs)
- Faucet: https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet

### Arbitrum Sepolia

- PoolManager: (Check docs)
- Faucet: https://faucet.quicknode.com/arbitrum/sepolia

## Troubleshooting

### "Set POOL_MANAGER address" Error

- Update the `POOL_MANAGER` constant in TestnetDemo.s.sol

### Hook Deployment Fails

- Set `DEPLOY_HOOK = false` to skip hook deployment
- Hook requires specific address bit flags (CREATE2 salt mining)
- May need more attempts or different CREATE2 deployer

### Execution Fails

- Ensure you have test tokens deployed
- Check token approvals for LiquidityBuffer
- Verify pool is initialized
- Make sure hook validation passes (if deployed)

## Recommended Approach for Hackathon Demo

1. **Deploy core contracts only** (skip hook)
2. **Create intents on testnet** (proves on-chain functionality)
3. **Show local tests** (proves full logic works)
4. **Explain hook** would be deployed in production with proper salt mining

This gives you real on-chain transactions without the complexity of hook deployment!
