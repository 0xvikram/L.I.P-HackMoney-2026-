// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";

contract IntentManager {
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
    /// @dev called by executor after successful liquidity add
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
    function cancelIntent(uint256 intentId) external {
        Intent storage i = intents[intentId];
        require(i.lp == msg.sender, "not intent owner");
        require(i.active, "already inactive");

        i.active = false;
    }

    /// @notice Get an intent by ID
    function getIntent(uint256 intentId) external view returns (Intent memory) {
        return intents[intentId];
    }
}
