// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IntentManager} from "./IntentManager.sol";
import {LiquidityBuffer} from "./LiquidityBuffer.sol";

/// @title ChunkExecutor
/// @notice Permissionless executor for progressive liquidity provisioning
/// @dev Anyone can call executeChunk to add liquidity according to intent parameters
contract ChunkExecutor {
    IPoolManager public immutable poolManager;
    IntentManager public immutable intentManager;
    LiquidityBuffer public immutable buffer;

    constructor(address _poolManager, address _intentManager, address _buffer) {
        poolManager = IPoolManager(_poolManager);
        intentManager = IntentManager(_intentManager);
        buffer = LiquidityBuffer(_buffer);
    }

    /// @notice Execute a bounded chunk of liquidity for an intent
    /// @dev Permissionless execution - anyone can call to execute intent chunks
    /// @dev Flow: 1) Read intent 2) Validate chunk 3) Call poolManager.modifyLiquidity 4) Mark executed
    /// @param intentId The ID of the intent to execute
    /// @param chunkLiquidity Amount of liquidity to add in this execution (must be ≤ maxChunk)
    function executeChunk(uint256 intentId, uint128 chunkLiquidity) external {
        // 1. Read intent
        IntentManager.Intent memory i = intentManager.getIntent(intentId);

        // 2. Basic checks
        require(i.active, "LIP: intent inactive");
        require(chunkLiquidity > 0, "LIP: chunk=0");
        require(chunkLiquidity <= i.maxChunk, "LIP: chunk too large");
        require(
            i.executedLiquidity + chunkLiquidity <= i.totalLiquidity,
            "LIP: exceeds intent"
        );

        // 3. (Hackathon simplification)
        // We assume tokens are already in buffer and approvals are handled.
        // Exact token math is out of scope for MVP.

        // 4. Add liquidity to Uniswap v4 pool
        poolManager.modifyLiquidity(
            i.pool,
            ModifyLiquidityParams({
                tickLower: i.tickLower,
                tickUpper: i.tickUpper,
                liquidityDelta: int128(chunkLiquidity),
                salt: bytes32(0)
            }),
            // Intent context passed to hook
            abi.encode(intentId)
        );

        // 5. Mark execution
        intentManager.markExecuted(intentId, chunkLiquidity);
    }
}
