// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BaseHook} from "@openzeppelin/uniswap-hooks/src/base/BaseHook.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {IPoolManager, ModifyLiquidityParams} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";

contract LIPHook is BaseHook {
    /// @notice authorized executor (ChunkExecutor)
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

    function beforeAddLiquidity(
        address sender,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata data
    ) external override returns (bytes4) {
        // Block all direct LP adds
        require(sender == executor, "LIP: direct LP blocked");

        // Require intent context
        require(data.length > 0, "LIP: intent required");

        return this.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        // Liquidity removal is also intent-based (future)
        revert("LIP: remove blocked");
    }

    /*//////////////////////////////////////////////////////////////
                            SWAPS
    //////////////////////////////////////////////////////////////*/

    // We do NOT touch swaps — this is LP-only enforcement
}
