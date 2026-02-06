// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

contract LiquidityBuffer {
    // intentId => token => amount
    mapping(uint256 => mapping(address => uint256)) public balances;

    event Deposited(
        uint256 indexed intentId,
        address indexed token,
        uint256 amount
    );

    event Released(
        uint256 indexed intentId,
        address indexed token,
        address indexed to,
        uint256 amount
    );

    /// @notice Deposit tokens for a specific intent
    function deposit(uint256 intentId, address token, uint256 amount) external {
        require(amount > 0, "amount=0");

        IERC20(token).transferFrom(msg.sender, address(this), amount);

        balances[intentId][token] += amount;

        emit Deposited(intentId, token, amount);
    }

    /// @notice Release tokens during chunk execution
    /// @dev access control will be added later (executor only)
    function release(
        uint256 intentId,
        address token,
        address to,
        uint256 amount
    ) external {
        require(balances[intentId][token] >= amount, "insufficient balance");

        balances[intentId][token] -= amount;
        IERC20(token).transfer(to, amount);

        emit Released(intentId, token, to, amount);
    }

    /// @notice Withdraw remaining buffered funds after intent cancellation
    function withdrawRemaining(
        uint256 intentId,
        address token,
        address to
    ) external {
        uint256 amount = balances[intentId][token];
        require(amount > 0, "nothing to withdraw");

        balances[intentId][token] = 0;
        IERC20(token).transfer(to, amount);

        emit Released(intentId, token, to, amount);
    }
}
