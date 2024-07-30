// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Errors} from "./Errors.sol";
import {ERC20} from "../../open-zeppelin/ERC20.sol";
import {SafeTransferLib} from "../../open-zeppelin/utils/SafeTransferLib.sol";
import {IVault} from "../interfaces/IVault.sol";
import {EtherUtils} from "../utils/EtherUtils.sol";

abstract contract ABalancer is EtherUtils {
    using SafeTransferLib for ERC20;

    // Base mainnet address of IMO.
    address internal constant IMO = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF;

    // Base mainnet address balanlcer vault.
    address public vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    // Base mainnet id for balancer IMO-WETH pool.
    bytes32 public poolId = 0x7120fd744ca7b45517243ce095c568fd88661c66000200000000000000000179;

    /// @notice Emitted when the Balancer vault address is updated.
    /// @param newVault The address of the new Balancer vault.
    event SetBalancerVault(address newVault);

    /// @notice Emitted when the Balancer pool ID is updated.
    /// @param newPoolId The new pool ID.
    event SetBalancerPoolId(bytes32 newPoolId);

    /// @notice Sets a new address for the Balancer vault.
    /// @param _vault The address of the new Balancer vault.
    function setBalancerVault(address _vault) external onlyOwner {
        if (_vault == address(0)) revert Errors.ZeroAddress();
        vault = _vault;

        emit SetBalancerVault(_vault);
    }

    /// @notice Sets a new pool ID for Balancer operations.
    /// @param _poolId The new pool ID.
    function setBalancerPoolId(bytes32 _poolId) external onlyOwner {
        poolId = _poolId;

        emit SetBalancerPoolId(_poolId);
    }

    /// @notice Resets WETH allowance for the specified Balancer vault.
    function resetBalancerAllowance() external onlyOwner {
        _resetWethAllowance(vault);
    }

    /// @notice Removes WETH allowance for the specified Balancer vault.
    function removeBalancerAllowance() external onlyOwner {
        _removeWethAllowance(vault);
    }

    /// @dev Converts a given amount of WETH into IMO using the specified Balancer pool.
    /// @param amount The amount of WETH to be exchanged.
    /// @param imoOutMin The minimum amount of AURA expected in return.
    function _wethToAura(uint256 amount, uint256 imoOutMin) internal {
        IVault.SingleSwap memory params = IVault.SingleSwap({
            poolId: poolId,
            kind: 0, // exact input, output given
            assetIn: WETH,
            assetOut: IMO,
            amount: amount, // Amount to swap
            userData: ""
        });

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: address(this), // Funds are taken from this contract
            recipient: address(this), // Swapped tokens are sent back to this contract
            fromInternalBalance: false, // Don't take funds from contract LPs (since there's none)
            toInternalBalance: false // Don't LP with swapped funds
        });

        IVault(vault).swap(params, funds, imoOutMin, block.timestamp);
    }
}