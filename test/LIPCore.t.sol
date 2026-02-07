// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";

import {LiquidityBuffer} from "../src/LIP/LiquidityBuffer.sol";
import {IntentManager} from "../src/LIP/IntentManager.sol";
import {ChunkExecutor} from "../src/LIP/ChunkExecutor.sol";

/**
 * @title LIP Core Tests
 * @notice Tests for Intent-Based Liquidity Protocol core functionality
 * @dev Tests IntentManager and ChunkExecutor without full pool integration
 */
contract LIPCoreTest is Test {
    // Core contracts
    address public mockPoolManager;
    LiquidityBuffer public buffer;
    IntentManager public intentManager;
    ChunkExecutor public executor;

    // Test addresses
    address public alice = address(0xA11CE);
    address public bob = address(0xB0B);
    address public charlie = address(0xC);

    // Mock pool key
    PoolKey public poolKey;

    function setUp() public {
        console.log("=== LIP CORE TEST SETUP ===\n");

        // Use mock pool manager address
        mockPoolManager = address(0x1111111111111111111111111111111111111111);

        // Deploy LIP contracts
        buffer = new LiquidityBuffer();
        intentManager = new IntentManager();
        executor = new ChunkExecutor(
            mockPoolManager,
            address(intentManager),
            address(buffer)
        );

        // Setup mock pool key
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0x1)),
            currency1: Currency.wrap(address(0x2)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);

        console.log("MockPoolManager:", mockPoolManager);
        console.log("IntentManager:", address(intentManager));
        console.log("ChunkExecutor:", address(executor));
        console.log("LiquidityBuffer:", address(buffer));
        console.log("");
    }

    /*//////////////////////////////////////////////////////////////
                        INTENT CREATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateIntent_Success() public {
        vm.startPrank(alice);

        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100, // tickLower
            100, // tickUpper
            1000, // totalLiquidity
            100 // maxChunk
        );

        assertEq(intentId, 1, "Intent ID should be 1");

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(intent.lp, alice, "LP should be alice");
        assertEq(intent.totalLiquidity, 1000, "Total liquidity should be 1000");
        assertEq(intent.maxChunk, 100, "Max chunk should be 100");
        assertEq(intent.executedLiquidity, 0, "Executed liquidity should be 0");
        assertTrue(intent.active, "Intent should be active");

        vm.stopPrank();
    }

    function test_CreateIntent_RevertsOnZeroLiquidity() public {
        vm.startPrank(alice);

        vm.expectRevert("liquidity=0");
        intentManager.createIntent(poolKey, -100, 100, 0, 100);

        vm.stopPrank();
    }

    function test_CreateIntent_RevertsOnZeroMaxChunk() public {
        vm.startPrank(alice);

        vm.expectRevert("maxChunk=0");
        intentManager.createIntent(poolKey, -100, 100, 1000, 0);

        vm.stopPrank();
    }

    function test_CreateIntent_RevertsOnChunkGreaterThanTotal() public {
        vm.startPrank(alice);

        vm.expectRevert("chunk>total");
        intentManager.createIntent(poolKey, -100, 100, 1000, 2000);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INTENT CANCELLATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CancelIntent_Success() public {
        vm.startPrank(alice);

        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );
        intentManager.cancelIntent(intentId);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertFalse(intent.active, "Intent should be inactive");

        vm.stopPrank();
    }

    function test_CancelIntent_RevertsOnNonOwner() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        vm.prank(bob);
        vm.expectRevert("not intent owner");
        intentManager.cancelIntent(intentId);
    }

    function test_CancelIntent_RevertsOnAlreadyInactive() public {
        vm.startPrank(alice);

        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );
        intentManager.cancelIntent(intentId);

        vm.expectRevert("already inactive");
        intentManager.cancelIntent(intentId);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        INTENT EXECUTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_MarkExecuted_Success() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        intentManager.markExecuted(intentId, 100);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(
            intent.executedLiquidity,
            100,
            "Executed liquidity should be 100"
        );
        assertTrue(intent.active, "Intent should still be active");
    }

    function test_MarkExecuted_DeactivatesWhenComplete() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        intentManager.markExecuted(intentId, 1000);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 1000, "All liquidity executed");
        assertFalse(intent.active, "Intent should be inactive when complete");
    }

    function test_MarkExecuted_RevertsOnOverExecution() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        vm.expectRevert("over-execute");
        intentManager.markExecuted(intentId, 1001);
    }

    function test_MarkExecuted_RevertsOnInactiveIntent() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        vm.prank(alice);
        intentManager.cancelIntent(intentId);

        vm.expectRevert("inactive intent");
        intentManager.markExecuted(intentId, 100);
    }

    function test_MarkExecuted_RevertsOnZeroAmount() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        vm.expectRevert("amount=0");
        intentManager.markExecuted(intentId, 0);
    }

    /*//////////////////////////////////////////////////////////////
                        INTEGRATION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FullIntentFlow_MultipleChunks() public {
        console.log("=== FULL INTENT FLOW TEST ===\n");

        // Alice creates intent for 1000 liquidity, max 250 per chunk
        vm.startPrank(alice);
        console.log("Step 1: Alice creates intent (1000 total, 250 max chunk)");

        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            250
        );
        console.log("Intent ID:", intentId);
        vm.stopPrank();

        // Execute in 4 chunks
        console.log("\nStep 2: Execute chunk 1 (250)");
        intentManager.markExecuted(intentId, 250);
        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 250);
        assertTrue(intent.active);

        console.log("Step 3: Execute chunk 2 (250)");
        intentManager.markExecuted(intentId, 250);
        intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 500);
        assertTrue(intent.active);

        console.log("Step 4: Execute chunk 3 (250)");
        intentManager.markExecuted(intentId, 250);
        intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 750);
        assertTrue(intent.active);

        console.log("Step 5: Execute chunk 4 (250 - completes intent)");
        intentManager.markExecuted(intentId, 250);
        intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 1000);
        assertFalse(intent.active, "Intent complete");

        console.log("\nFull flow completed successfully\n");
    }

    function test_MultipleUsers_MultipleIntents() public {
        // Alice creates intent 1
        vm.prank(alice);
        uint256 intent1 = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        // Bob creates intent 2
        vm.prank(bob);
        uint256 intent2 = intentManager.createIntent(
            poolKey,
            -200,
            200,
            2000,
            200
        );

        // Charlie creates intent 3
        vm.prank(charlie);
        uint256 intent3 = intentManager.createIntent(poolKey, -50, 50, 500, 50);

        assertEq(intent1, 1);
        assertEq(intent2, 2);
        assertEq(intent3, 3);

        IntentManager.Intent memory aliceIntent = intentManager.getIntent(
            intent1
        );
        IntentManager.Intent memory bobIntent = intentManager.getIntent(
            intent2
        );
        IntentManager.Intent memory charlieIntent = intentManager.getIntent(
            intent3
        );

        assertEq(aliceIntent.lp, alice);
        assertEq(bobIntent.lp, bob);
        assertEq(charlieIntent.lp, charlie);

        assertEq(aliceIntent.totalLiquidity, 1000);
        assertEq(bobIntent.totalLiquidity, 2000);
        assertEq(charlieIntent.totalLiquidity, 500);
    }

    function test_PartialExecution_ThenCancel() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        // Execute 300 out of 1000
        intentManager.markExecuted(intentId, 300);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 300);
        assertTrue(intent.active);

        // Alice cancels remaining execution
        vm.prank(alice);
        intentManager.cancelIntent(intentId);

        intent = intentManager.getIntent(intentId);
        assertEq(intent.executedLiquidity, 300, "Executed amount preserved");
        assertFalse(intent.active, "Intent cancelled");

        // Cannot execute more
        vm.expectRevert("inactive intent");
        intentManager.markExecuted(intentId, 100);
    }

    /*//////////////////////////////////////////////////////////////
                        EDGE CASE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EdgeCase_MaxChunkEqualsTotal() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            1000
        );

        // Can execute all at once
        intentManager.markExecuted(intentId, 1000);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertFalse(intent.active, "Completes in one chunk");
    }

    function test_EdgeCase_MinimalValues() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(poolKey, -100, 100, 1, 1);

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(intent.totalLiquidity, 1);
        assertEq(intent.maxChunk, 1);
    }

    function test_EdgeCase_VeryLargeLiquidity() public {
        uint128 largeLiquidity = type(uint128).max;

        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            largeLiquidity,
            largeLiquidity / 2
        );

        IntentManager.Intent memory intent = intentManager.getIntent(intentId);
        assertEq(intent.totalLiquidity, largeLiquidity);
    }

    /*//////////////////////////////////////////////////////////////
                        SECURITY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Security_CannotCancelOthersIntent() public {
        vm.prank(alice);
        uint256 intentId = intentManager.createIntent(
            poolKey,
            -100,
            100,
            1000,
            100
        );

        vm.prank(bob);
        vm.expectRevert("not intent owner");
        intentManager.cancelIntent(intentId);
    }

    function test_Security_SequentialIntentIds() public {
        vm.prank(alice);
        uint256 id1 = intentManager.createIntent(poolKey, -100, 100, 1000, 100);

        vm.prank(bob);
        uint256 id2 = intentManager.createIntent(poolKey, -100, 100, 2000, 200);

        vm.prank(charlie);
        uint256 id3 = intentManager.createIntent(poolKey, -100, 100, 3000, 300);

        assertEq(id1, 1);
        assertEq(id2, 2);
        assertEq(id3, 3);
    }
}
