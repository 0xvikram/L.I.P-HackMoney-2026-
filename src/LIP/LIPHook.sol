// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

/// @title LIPHook
/// @notice Uniswap v4 hook enforcing intent-based liquidity provisioning
/// @dev Blocks all direct LP adds/removes, only allows ChunkExecutor with intent context
contract LIPHook is BaseHook {
    /// @notice Authorized executor address (ChunkExecutor contract)
    /// @dev Only this address can add liquidity, and must provide intent context
    address public executor;

    constructor(
        IPoolManager _poolManager,
        address _executor
    ) BaseHook(_poolManager) {
        executor = _executor;
    }

    function getHookPermissions()
        public
        pure
        override
        returns (Hooks.Permissions memory)
    {
        return
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: true,
                afterRemoveLiquidity: false,
                beforeSwap: false,
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            });
    }

    /*//////////////////////////////////////////////////////////////
                            LIQUIDITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Hook called before adding liquidity to enforce intent-based execution
    /// @dev Validates that sender is executor and intent context is provided
    /// @param sender The address attempting to add liquidity (must be executor)
    /// @param data Must contain intent context (intentId) for validation
    /// @return Function selector indicating successful validation
    function beforeAddLiquidity(
        address sender,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata data
    ) external view override returns (bytes4) {
        // Block all direct LP adds
        require(sender == executor, "LIP: direct LP blocked");

        // Require intent context
        require(data.length > 0, "LIP: intent required");

        return this.beforeAddLiquidity.selector;
    }

    /// @notice Hook called before removing liquidity - currently blocked
    /// @dev All liquidity removals are blocked in current version (future: intent-based removal)
    /// @return Never returns - always reverts
    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        // Liquidity removal is also intent-based (future)
        revert("LIP: remove blocked");
    }

    /*//////////////////////////////////////////////////////////////
                            SWAPS
    //////////////////////////////////////////////////////////////*/

    
}
