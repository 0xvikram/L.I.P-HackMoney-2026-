// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "forge-std/console.sol";

import {LiquidityBuffer} from "../src/LIP/LiquidityBuffer.sol";
import {IntentManager} from "../src/LIP/IntentManager.sol";
import {ChunkExecutor} from "../src/LIP/ChunkExecutor.sol";

// Simplified deployment for testing core LIP contracts
// Skips pool creation to avoid hook address complexity for hackathon demo

contract SimpleLIPDeploy is Script {
    function run() external {
        console.log("=== SIMPLE LIP DEPLOYMENT ===");
        console.log("Deployer:", msg.sender);
        
        vm.startBroadcast();

        // For hackathon demo: use mock pool manager address
        address mockPoolManager = address(0x1111111111111111111111111111111111111111);
        console.log("Using mock PoolManager:", mockPoolManager);

        // Deploy LIP core contracts
        LiquidityBuffer buffer = new LiquidityBuffer();
        console.log("LiquidityBuffer:", address(buffer));
        
        IntentManager intentManager = new IntentManager();
        console.log("IntentManager:", address(intentManager));

        ChunkExecutor executor = new ChunkExecutor(
            mockPoolManager,
            address(intentManager),
            address(buffer)
        );
        console.log("ChunkExecutor:", address(executor));

        vm.stopBroadcast();

        console.log("\n=== DEPLOYMENT COMPLETE ===");
        console.log("Core LIP contracts deployed successfully!");
        console.log("Ready for testing with mock pool manager.");
    }
}
