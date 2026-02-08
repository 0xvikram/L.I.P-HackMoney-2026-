// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";

import {LiquidityBuffer} from "../src/LIP/LiquidityBuffer.sol";
import {IntentManager} from "../src/LIP/IntentManager.sol";
import {ChunkExecutor} from "../src/LIP/ChunkExecutor.sol";
import {LIPHook} from "../src/LIP/LIPHook.sol";

/// @title LIP Testnet Demo Script
/// @notice Deploy and demonstrate LIP on a testnet with existing Uniswap v4
/// @dev Requires: Uniswap v4 PoolManager deployed on testnet
///
/// USAGE:
/// 1. Set environment variables in .env:
///    POOL_MANAGER_ADDRESS=0x... (Uniswap v4 PoolManager on testnet)
///    TESTNET_RPC_URL=https://...
///    PRIVATE_KEY=0x...
///
/// 2. Run:
///    source .env
///    forge script script/TestnetDemo.s.sol \
///      --rpc-url $TESTNET_RPC_URL \
///      --private-key $PRIVATE_KEY \
///      --broadcast -vvv
///
/// TESTNET ADDRESSES (as of Feb 2026):
/// - Sepolia: Check https://docs.uniswap.org/contracts/v4/deployments
/// - Base Sepolia: Check https://docs.uniswap.org/contracts/v4/deployments
/// - Arbitrum Sepolia: Check https://docs.uniswap.org/contracts/v4/deployments

contract TestnetDemo is Script {
    // ========== CONFIGURATION ==========
    // Update these for your testnet deployment

    // Real Uniswap v4 PoolManager on Sepolia (as of Feb 2026)
    address constant POOL_MANAGER = 0xE03A1074c86CFeDd5C142C4F04F1a1536e203543;

    // Set to true if you want to attempt hook deployment with salt mining
    // WARNING: This can take time and may fail if no valid salt is found
    bool constant DEPLOY_HOOK = false;

    // Set to true to skip actual liquidity execution (just test intent creation)
    bool constant SKIP_EXECUTION = true;

    // ===================================

    LiquidityBuffer buffer;
    IntentManager intentManager;
    ChunkExecutor executor;
    LIPHook hook;

    address deployer;

    function run() external {
        // Note: Using mock PoolManager for demo - update constant for real v4 deployment
        
        deployer = msg.sender;

        console.log("\n");
        console.log("===============================================");
        console.log("   LIP TESTNET DEPLOYMENT");
        console.log("===============================================");
        console.log("Network:", block.chainid);
        console.log("PoolManager:", POOL_MANAGER);
        console.log("Deployer:", deployer);
        console.log("\n");

        vm.startBroadcast();

        // STEP 1: Deploy LIP core contracts
        deployCore();

        // STEP 2: Optionally deploy hook (requires salt mining)
        if (DEPLOY_HOOK) {
            deployHook();
        }

        vm.stopBroadcast();

        // STEP 3: Demonstrate functionality
        if (!SKIP_EXECUTION) {
            demonstrateIntents();
        } else {
            console.log(
                "\n[INFO] Skipping execution demo (SKIP_EXECUTION=true)"
            );
            console.log("Contracts deployed successfully!");
            console.log("\nYou can now:");
            console.log("  1. Create intents via IntentManager.createIntent()");
            console.log("  2. Execute chunks via ChunkExecutor.executeChunk()");
        }

        printDeploymentSummary();
    }

    function deployCore() internal {
        console.log("STEP 1: Deploying LIP Core Contracts\n");

        buffer = new LiquidityBuffer();
        console.log("  [+] LiquidityBuffer:", address(buffer));

        intentManager = new IntentManager();
        console.log("  [+] IntentManager:", address(intentManager));

        executor = new ChunkExecutor(
            POOL_MANAGER,
            address(intentManager),
            address(buffer)
        );
        console.log("  [+] ChunkExecutor:", address(executor));
        console.log("");
    }

    function deployHook() internal {
        console.log("STEP 2: Deploying LIPHook (Salt Mining)\n");
        console.log("  [!] WARNING: This may take time or fail\n");

        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );

        // Try to find valid salt (limit attempts for testnet)
        bytes32 salt = 0;
        address hookAddress;
        uint256 attempts = 0;
        uint256 maxAttempts = 1000; // Limit for testnet

        console.log("  Mining for valid hook address...");

        while (attempts < maxAttempts) {
            salt = bytes32(attempts);

            // Predict address
            bytes32 hash = keccak256(
                abi.encodePacked(
                    bytes1(0xff),
                    address(this),
                    salt,
                    keccak256(
                        abi.encodePacked(
                            type(LIPHook).creationCode,
                            abi.encode(
                                IPoolManager(POOL_MANAGER),
                                address(executor)
                            )
                        )
                    )
                )
            );
            hookAddress = address(uint160(uint256(hash)));

            // Check if flags match
            if ((uint160(hookAddress) & flags) == flags) {
                console.log(
                    "  [+] Found valid address after attempts:",
                    attempts
                );
                break;
            }

            attempts++;
        }

        if (attempts >= maxAttempts) {
            console.log(
                "  [X] Could not find valid hook address in",
                maxAttempts,
                "attempts"
            );
            console.log("  [!] Skipping hook deployment");
            return;
        }

        // Deploy with found salt
        hook = new LIPHook{salt: salt}(
            IPoolManager(POOL_MANAGER),
            address(executor)
        );
        require(address(hook) == hookAddress, "Hook address mismatch");

        console.log("  [+] LIPHook deployed:", address(hook));
        console.log("");
    }

    function demonstrateIntents() internal {
        console.log("\nSTEP 3: Demonstrating Intent Creation\n");

        // For testnet, we just create intents without executing
        // Real execution would require:
        // - Real tokens with approvals
        // - Actual pool initialization
        // - Hook validation passing

        console.log("  [!] NOTE: Real execution requires:");
        console.log("      - Test tokens deployed");
        console.log("      - Token approvals for buffer");
        console.log("      - Pool initialized with hook");
        console.log("      - Sufficient test token balance");
        console.log("\n  For now, contract deployment is complete.");
        console.log(
            "  Use IntentManager.createIntent() to create intents manually."
        );
    }

    function printDeploymentSummary() internal view {
        console.log("\n");
        console.log("===============================================");
        console.log("         DEPLOYMENT SUMMARY");
        console.log("===============================================");
        console.log("");
        console.log("Network Chain ID:", block.chainid);
        console.log("");
        console.log("DEPLOYED CONTRACTS:");
        console.log("  LiquidityBuffer:  ", address(buffer));
        console.log("  IntentManager:    ", address(intentManager));
        console.log("  ChunkExecutor:    ", address(executor));
        if (address(hook) != address(0)) {
            console.log("  LIPHook:          ", address(hook));
        } else {
            console.log("  LIPHook:           [NOT DEPLOYED]");
        }
        console.log("");
        console.log("UNISWAP V4:");
        console.log("  PoolManager:      ", POOL_MANAGER);
        console.log("");
        console.log("NEXT STEPS:");
        console.log("  1. Verify contracts on block explorer");
        console.log("  2. Create test intent:");
        console.log('     cast send <IntentManager> "createIntent(...)"');
        console.log("  3. Execute chunks:");
        console.log(
            '     cast send <ChunkExecutor> "executeChunk(uint256,uint128)"'
        );
        console.log("");
        console.log("===============================================");
        console.log("\n");
    }
}
