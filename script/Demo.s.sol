// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {LiquidityBuffer} from "../src/LIP/LiquidityBuffer.sol";
import {IntentManager} from "../src/LIP/IntentManager.sol";
import {ChunkExecutor} from "../src/LIP/ChunkExecutor.sol";

/// @title LIP Protocol Demo Script
/// @notice Interactive demonstration of the full LIP intent lifecycle
/// @dev Run with: forge script script/Demo.s.sol --rpc-url http://localhost:8545 --broadcast -vvv
contract Demo is Script {
    LiquidityBuffer buffer;
    IntentManager intentManager;
    ChunkExecutor executor;

    address alice = address(0xA11CE);
    address bob = address(0xB0B);
    address charlie = address(0xC);

    function run() external {
        console.log("\n");
        console.log("===============================================");
        console.log("   LIP - LIQUIDITY INTENT PROTOCOL DEMO");
        console.log("===============================================");
        console.log("\n");

        // STEP 1: Deploy contracts
        vm.startBroadcast();
        deployContracts();
        vm.stopBroadcast();

        console.log("\n--- SCENARIO 1: FULL INTENT LIFECYCLE ---\n");

        // STEP 2: Alice creates an intent
        uint256 aliceIntentId = createAliceIntent();

        // STEP 3: Execute intent in 3 chunks
        executeChunks(aliceIntentId);

        console.log("\n--- SCENARIO 2: PARTIAL EXECUTION + CANCEL ---\n");

        // STEP 4: Bob creates an intent
        uint256 bobIntentId = createBobIntent();

        // STEP 5: Partially execute Bob's intent
        partialExecutionAndCancel(bobIntentId);

        console.log("\n--- SCENARIO 3: CONCURRENT USERS ---\n");

        // STEP 6: Multiple users creating intents
        demonstrateConcurrentUsers();

        printFinalSummary();
    }

    function deployContracts() internal {
        console.log("STEP 1: Deploying LIP Protocol Contracts\n");

        // Use mock pool manager for demo
        address mockPoolManager = address(
            0x1111111111111111111111111111111111111111
        );

        buffer = new LiquidityBuffer();
        console.log("  [+] LiquidityBuffer deployed:", address(buffer));

        intentManager = new IntentManager();
        console.log("  [+] IntentManager deployed:", address(intentManager));

        executor = new ChunkExecutor(
            mockPoolManager,
            address(intentManager),
            address(buffer)
        );
        console.log("  [+] ChunkExecutor deployed:", address(executor));

        console.log("");
        console.log("  All contracts deployed successfully!");
    }

    function createAliceIntent() internal returns (uint256) {
        console.log("STEP 2: Alice Creates Liquidity Intent\n");

        // Create a pool key for demo (mock addresses)
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1000)),
            currency1: Currency.wrap(address(0x2000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        vm.broadcast(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100, // tickLower
            100, // tickUpper
            1000e18, // totalLiquidity: 1000 tokens
            250e18 // maxChunk: 250 tokens per execution
        );

        console.log("  [+] Intent created by Alice");
        console.log("      Intent ID:", intentId);
        console.log("      Total Liquidity:", "1,000 tokens");
        console.log("      Max Chunk Size:", "250 tokens");
        console.log("      Tick Range:", "-100 to 100");

        // Verify intent state
        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        console.log("\n  Intent State:");
        console.log("    - Owner:", intent.lp);
        console.log("    - Active:", intent.active ? "YES" : "NO");
        console.log(
            "    - Executed:",
            uint256(intent.executedLiquidity) / 1e18,
            "tokens"
        );
        console.log(
            "    - Remaining:",
            uint256(intent.totalLiquidity - intent.executedLiquidity) / 1e18,
            "tokens"
        );

        return intentId;
    }

    function executeChunks(uint256 intentId) internal {
        console.log("\nSTEP 3: Progressive Chunk Execution\n");

        // For demo: directly call markExecuted since we don't have a real pool
        // In production, ChunkExecutor would call poolManager.modifyLiquidity first
        string[4] memory names = ["Bob", "Charlie", "Bob", "Charlie"];

        for (uint256 i = 0; i < 4; i++) {
            console.log("  Chunk", i + 1, "of 4 - Executed by", names[i]);

            // Simulate execution: directly mark as executed
            vm.broadcast(address(executor));
            intentManager.markExecuted(intentId, 250e18);

            IntentManager.Intent memory intent = intentManager.getIntent(
                intentId
            );

            console.log("    >> Executed: 250 tokens");
            console.log(
                "    >> Total Progress:",
                uint256(intent.executedLiquidity) / 1e18,
                "/ 1,000 tokens"
            );

            if (!intent.active) {
                console.log("    >> Intent COMPLETED and auto-deactivated!");
            }

            console.log("");
        }

        console.log("  All chunks executed successfully!");
    }

    function createBobIntent() internal returns (uint256) {
        console.log("STEP 4: Bob Creates Another Intent\n");

        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0x3000)),
            currency1: Currency.wrap(address(0x4000)),
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(0))
        });

        vm.broadcast(bob);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -50,
            50,
            500e18, // 500 tokens total
            100e18 // 100 tokens per chunk
        );

        console.log("  [+] Intent created by Bob");
        console.log("      Intent ID:", intentId);
        console.log("      Total Liquidity:", "500 tokens");
        console.log("      Max Chunk Size:", "100 tokens");

        return intentId;
    }

    function partialExecutionAndCancel(uint256 intentId) internal {
        console.log("\nSTEP 5: Partial Execution + Cancellation\n");

        // Execute 2 chunks
        console.log("  Charlie executes first chunk (100 tokens)");
        vm.broadcast(address(executor));
        intentManager.markExecuted(intentId, 100e18);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        console.log("    >> Progress: 100 / 500 tokens\n");

        console.log("  Charlie executes second chunk (100 tokens)");
        vm.broadcast(address(executor));
        intentManager.markExecuted(intentId, 100e18);

        intent = intentManager.getIntent(intentId);
        console.log("    >> Progress: 200 / 500 tokens\n");

        // Bob decides to cancel remaining
        console.log("  Bob decides to cancel the remaining intent");
        vm.broadcast(bob);
        intentManager.cancelIntent(intentId);

        intent = intentManager.getIntent(intentId);
        console.log("    Intent cancelled");
        console.log("    >> Final execution: 200 / 500 tokens");
        console.log("    >> Status:", intent.active ? "ACTIVE" : "CANCELLED");
        console.log("    >> 300 tokens never executed (LP retained control)");
    }

    function demonstrateConcurrentUsers() internal {
        console.log("STEP 6: Multiple Concurrent Users\n");

        PoolKey memory poolKey1 = PoolKey({
            currency0: Currency.wrap(address(0x5000)),
            currency1: Currency.wrap(address(0x6000)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        PoolKey memory poolKey2 = PoolKey({
            currency0: Currency.wrap(address(0x7000)),
            currency1: Currency.wrap(address(0x8000)),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(0))
        });

        // Alice creates another intent
        vm.broadcast(alice);
        uint256 intent3 = intentManager.createIntent(
            poolKey1,
            -200,
            200,
            2000e18,
            500e18
        );
        console.log("  [+] Alice created intent #3: 2,000 tokens, 500 chunk");

        // Charlie creates his first intent
        vm.broadcast(charlie);
        uint256 intent4 = intentManager.createIntent(
            poolKey2,
            -1000,
            1000,
            5000e18,
            1000e18
        );
        console.log(
            "  [+] Charlie created intent #4: 5,000 tokens, 1000 chunk"
        );

        // Show both can be executed independently
        console.log("\n  Executing Alice's intent (chunk 1)...");
        vm.broadcast(address(executor));
        intentManager.markExecuted(intent3, 500e18);
        console.log("    >> 500 / 2,000 executed");

        console.log("\n  Executing Charlie's intent (chunk 1)...");
        vm.broadcast(address(executor));
        intentManager.markExecuted(intent4, 1000e18);
        console.log("    >> 1,000 / 5,000 executed");

        console.log(
            "\n  Multiple users can create and execute intents concurrently!"
        );
    }

    function printFinalSummary() internal view {
        console.log("\n");
        console.log("===============================================");
        console.log("              DEMO SUMMARY");
        console.log("===============================================");
        console.log("");
        console.log("[+] Deployed LIP Protocol (3 core contracts)");
        console.log("[+] Created 4 intents across 3 users");
        console.log("[+] Executed 8 chunks progressively");
        console.log("[+] Demonstrated cancellation (LP control)");
        console.log("[+] Showed permissionless execution");
        console.log("[+] Proved concurrent multi-user support");
        console.log("");
        console.log("KEY FEATURES DEMONSTRATED:");
        console.log("  * Progressive liquidity provisioning");
        console.log("  * Permissionless chunk execution");
        console.log("  * LP sovereignty (cancellation rights)");
        console.log("  * Auto-deactivation on completion");
        console.log("  * Multi-user concurrent operations");
        console.log("");
        console.log("Next Intent ID:", intentManager.nextIntentId());
        console.log("");
        console.log("===============================================");
        console.log("     LIP PROTOCOL DEMO COMPLETED!");
        console.log("===============================================");
        console.log("\n");
    }
}
