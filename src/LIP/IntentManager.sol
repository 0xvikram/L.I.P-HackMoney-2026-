// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

/// @title IntentManager
/// @notice Manages the lifecycle of LP intents for progressive liquidity provision
/// @dev Core contract for creating, tracking, and cancelling liquidity intents
contract IntentManager {
    /// @notice Intent structure containing all liquidity provision parameters
    /// @param lp The address of the liquidity provider who created the intent
    /// @param pool The Uniswap v4 pool targeted for liquidity provision
    /// @param tickLower Lower tick bound of the liquidity range
    /// @param tickUpper Upper tick bound of the liquidity range
    /// @param totalLiquidity Total liquidity amount to be provided across all chunks
    /// @param executedLiquidity Amount of liquidity already executed
    /// @param maxChunk Maximum liquidity size allowed per single execution
    /// @param active Whether the intent is still active and can be executed
    struct Intent {
        address lp; // intent owner
        PoolKey pool; // target pool
        int24 tickLower; // LP range
        int24 tickUpper;
        uint128 totalLiquidity; // total liquidity to activate
        uint128 executedLiquidity; // how much is live
        uint128 maxChunk; // per-execution cap
        bool active;
    }

    uint256 public nextIntentId;
    mapping(uint256 => Intent) public intents;

    event IntentCreated(
        uint256 indexed intentId,
        address indexed lp,
        uint128 totalLiquidity,
        uint128 maxChunk
    );

    event IntentExecuted(
        uint256 indexed intentId,
        uint128 amountExecuted,
        uint128 totalExecuted
    );

    /// @notice Create a new liquidity intent
    /// @dev Validates intent parameters and stores in state with sequential ID
    /// @param pool The Uniswap v4 PoolKey specifying the target pool
    /// @param tickLower Lower tick bound for the liquidity range
    /// @param tickUpper Upper tick bound for the liquidity range
    /// @param totalLiquidity Total amount of liquidity to provide across all executions
    /// @param maxChunk Maximum liquidity size per execution (prevents single large adds)
    /// @return intentId The unique identifier for this intent
    function createIntent(
        PoolKey calldata pool,
        int24 tickLower,
        int24 tickUpper,
        uint128 totalLiquidity,
        uint128 maxChunk
    ) external returns (uint256 intentId) {
        require(totalLiquidity > 0, "liquidity=0");
        require(maxChunk > 0, "maxChunk=0");
        require(maxChunk <= totalLiquidity, "chunk>total");

        intentId = ++nextIntentId;

        intents[intentId] = Intent({
            lp: msg.sender,
            pool: pool,
            tickLower: tickLower,
            tickUpper: tickUpper,
            totalLiquidity: totalLiquidity,
            executedLiquidity: 0,
            maxChunk: maxChunk,
            active: true
        });

        emit IntentCreated(intentId, msg.sender, totalLiquidity, maxChunk);
    }

    /// @notice Mark part of the intent as executed
    /// @dev Called by ChunkExecutor after successful liquidity add. Auto-deactivates when complete.
    /// @param intentId The ID of the intent being executed
    /// @param amount The amount of liquidity that was just added in this chunk
    function markExecuted(uint256 intentId, uint128 amount) external {
        Intent storage i = intents[intentId];
        require(i.active, "inactive intent");
        require(amount > 0, "amount=0");
        require(
            i.executedLiquidity + amount <= i.totalLiquidity,
            "over-execute"
        );

        i.executedLiquidity += amount;

        if (i.executedLiquidity == i.totalLiquidity) {
            i.active = false;
        }

        emit IntentExecuted(intentId, amount, i.executedLiquidity);
    }

    /// @notice Cancel an active intent and stop future execution
    /// @dev Only the original LP (intent creator) can cancel their intent
    /// @param intentId The ID of the intent to cancel
    function cancelIntent(uint256 intentId) external {
        Intent storage i = intents[intentId];
        require(i.lp == msg.sender, "not intent owner");
        require(i.active, "already inactive");

        i.active = false;
    }

    /// @notice Get an intent by ID
    /// @dev Returns the full Intent struct instead of tuple for easier access
    /// @param intentId The ID of the intent to retrieve
    /// @return The complete Intent struct with all parameters
    function getIntent(uint256 intentId) external view returns (Intent memory) {
        return intents[intentId];
    }
}
