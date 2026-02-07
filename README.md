# LIP - Liquidity Intent Protocol

**Intent-Based Liquidity Activation on Uniswap v4**

## Overview

LIP (Liquidity Intent Protocol) introduces **LP intents as a first-class primitive** on Uniswap v4, enforced non-bypassably through hooks. Instead of directly adding liquidity, LPs submit on-chain intents describing constraints (total liquidity, range, chunk bounds), and liquidity is activated gradually in bounded chunks.

### The Problem

Liquidity Providers on AMMs leak valuable information through **timing and size of liquidity changes**. Even with private RPCs, once liquidity is added or removed, pool state updates are public and immediately exploitable, leading to adverse selection and MEV.

### The Solution

LIP removes **block-level precision** from LP actions by:

- Treating LP additions as **intents** rather than immediate executions
- Enforcing **gradual, chunked activation** at the pool level
- Making execution **permissionless** - anyone can execute chunks
- Guaranteeing **non-bypassable enforcement** via Uniswap v4 hooks

> This protocol does not hide information; it removes the precision that MEV relies on.

---

## Architecture

### 3-Layer Design

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: Intent Layer (On-chain)                           │
│  - LP submits intent (pool, range, total liquidity, bounds) │
│  - Funds held in LiquidityBuffer                            │
│  - No pool interaction yet                                  │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 2: Execution Layer (Permissionless)                  │
│  - Anyone calls executeChunk()                              │
│  - Pulls tokens from buffer                                 │
│  - Adds liquidity to pool in bounded amounts                │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│  Layer 3: Pool Enforcement (Hook)                           │
│  - beforeAddLiquidity: Blocks direct LP adds                │
│  - Only executor with intent data can proceed               │
│  - Non-bypassable enforcement                               │
└─────────────────────────────────────────────────────────────┘
```

### Core Contracts

- **[IntentManager.sol](src/LIP/IntentManager.sol)** - Intent creation, tracking, and lifecycle management
- **[LiquidityBuffer.sol](src/LIP/LiquidityBuffer.sol)** - Token custody and buffer storage
- **[ChunkExecutor.sol](src/LIP/ChunkExecutor.sol)** - Permissionless execution logic
- **[LIPHook.sol](src/LIP/LIPHook.sol)** - Uniswap v4 hook enforcement layer

---

## Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Solidity 0.8.26+

### Installation

```bash
git clone <repository-url>
cd L.I.P-HackMoney-2026-
forge install
forge build
```

### Run Tests

```bash
forge test
```

**Test Results:**

```
Ran 20 tests for test/LIPCore.t.sol:LIPCoreTest
[PASS] 20/20 tests passing
Suite result: ok. 20 passed; 0 failed; 0 skipped
```

### View Detailed Test Output

```bash
forge test --match-path test/LIPCore.t.sol -vv
```

---

## Testing Coverage

### Intent Creation (4 tests)

- ✅ Valid intent creation
- ✅ Reverts on zero liquidity
- ✅ Reverts on zero max chunk
- ✅ Reverts on chunk > total

### Intent Cancellation (3 tests)

- ✅ Successful cancellation
- ✅ Non-owner cannot cancel
- ✅ Cannot cancel twice

### Intent Execution (5 tests)

- ✅ Successful chunk execution
- ✅ Auto-deactivates when complete
- ✅ Reverts on over-execution
- ✅ Reverts on inactive intent
- ✅ Reverts on zero amount

### Integration Tests (3 tests)

- ✅ Full multi-chunk flow
- ✅ Multiple concurrent users
- ✅ Partial execution then cancel

### Edge Cases (3 tests)

- ✅ Max chunk equals total
- ✅ Minimal values (1,1)
- ✅ Maximum uint128 values

### Security (2 tests)

- ✅ Access control enforcement
- ✅ Sequential intent IDs

---

## Deployment

### Sepolia Testnet Deployment (LIVE)

**Deployed on February 8, 2026 - Block 10212411**

**Contract Addresses:**

```
LiquidityBuffer:   0x8dF2D3b60385325fF42a06850Fa11904fC6E242C
IntentManager:     0xE514254c1EBD1B55A5C4A981ff2ef2B7AeC43525
ChunkExecutor:     0xE19dA85545Ac7eAc44Fe356D76CbFdBaCa3819fd
```

**Etherscan Links:**

- [LiquidityBuffer](https://sepolia.etherscan.io/address/0x8dF2D3b60385325fF42a06850Fa11904fC6E242C)
- [IntentManager](https://sepolia.etherscan.io/address/0xE514254c1EBD1B55A5C4A981ff2ef2B7AeC43525)
- [ChunkExecutor](https://sepolia.etherscan.io/address/0xE19dA85545Ac7eAc44Fe356D76CbFdBaCa3819fd)

**Deployment Cost:** 0.0033 ETH (3,081,687 gas)

**Network Details:**

- Network: Sepolia Testnet
- Chain ID: 11155111
- RPC: https://sepolia.infura.io/v3/424c29054fa44622b7ad0d532e831712

### Local Deployment (Anvil)

The LIP protocol uses a simplified deployment approach suitable for testing and development.

1. **Start local blockchain**:

```bash
anvil
```

2. **Deploy LIP contracts**:

```bash
forge script script/SimpleLIPDeploy.s.sol \
    --rpc-url http://localhost:8545 \
    --private-key <PRIVATE_KEY> \
    --broadcast
```

This deploys:

- LiquidityBuffer (token custody)
- IntentManager (intent lifecycle)
- ChunkExecutor (permissionless execution)

**Deployed Addresses** will be shown in the output:

```
LiquidityBuffer: 0x...
IntentManager: 0x...
ChunkExecutor: 0x...
```

---

## Usage

### Creating an Intent

```solidity
import {IntentManager} from "./src/LIP/IntentManager.sol";

IntentManager intentManager = IntentManager(INTENT_MANAGER_ADDRESS);

// Define your intent parameters
uint128 totalLiquidity = 1000e18;
uint128 maxChunkSize = 100e18;

uint256 intentId = intentManager.createIntent(
    poolKey,          // Uniswap v4 PoolKey
    tickLower,        // Lower tick bound
    tickUpper,        // Upper tick bound
    totalLiquidity,   // Total liquidity to provide
    maxChunkSize      // Maximum per-chunk size
);
```

### Executing Intent Chunks

Anyone can execute chunks permissionlessly:

```solidity
import {ChunkExecutor} from "./src/LIP/ChunkExecutor.sol";

ChunkExecutor executor = ChunkExecutor(EXECUTOR_ADDRESS);

// Execute a chunk of an intent
executor.executeChunk(
    intentId,         // Intent ID from creation
    100e18           // Chunk amount (≤ maxChunkSize)
);
```

### Cancelling an Intent

Only the original LP can cancel:

```solidity
intentManager.cancelIntent(intentId);
```

---

## Gas Report

Generate a gas usage report:

```bash
forge test --gas-report
```

**Sample Results:**

```
| Contract        | Function      | Avg Gas  | Median  |
|-----------------|---------------|----------|---------|
| IntentManager   | createIntent  | ~150k    | 148k    |
| IntentManager   | cancelIntent  | ~30k     | 29k     |
| ChunkExecutor   | executeChunk  | ~180k    | 175k    |
```

---

## Design Philosophy

LIP (Liquidity Intent Protocol) separates **intent** from **execution** for Uniswap v4 LP positions. See [uniswapHoolIdea.md](../uniswapHoolIdea.md) for the full design document.

### Key Benefits

1. **Non-bypassable enforcement**: Hook prevents direct liquidity adds/removes
2. **Permissionless execution**: Anyone can execute chunks, enabling competitive markets
3. **LP sovereignty**: LPs retain control via cancellation rights
4. **Progressive execution**: Chunk-based execution reduces MEV and market impact

### Comparison to Alternatives

| Feature                  | LIP | Yellow | CoW Hook |
| ------------------------ | --- | ------ | -------- |
| Non-bypassable           | ✅  | ❌     | ❌       |
| Permissionless execution | ✅  | ❌     | ✅       |
| Intent cancellation      | ✅  | ✅     | ❌       |
| Gas efficient            | ✅  | ⚠️     | ✅       |

---

## Future Work

- [ ] **Token custody**: Implement buffer pre-funding and settlement
- [ ] **Fee mechanism**: Add executor incentives and protocol fees
- [ ] **Advanced strategies**: Support range orders, TWAP execution
- [ ] **Yellow integration**: Enable intent routing to Yellow Network
- [ ] **Production hardening**: Multi-sig controls, emergency pause, upgrade paths
- [ ] **Gas optimizations**: Batch execution, storage packing
- [ ] **Analytics**: On-chain metrics for intent completion rates

---

## Contributing

Built for **HackMoney 2026**. Contributions welcome!

## License

MIT License - see [LICENSE](LICENSE)

## Acknowledgments

- **Uniswap v4** for the hook framework
- **Foundry** for development tooling
- **OpenZeppelin** for base contracts
