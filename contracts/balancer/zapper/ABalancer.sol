// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import {Errors} from "./Errors.sol";
import {ERC20} from "../../open-zeppelin/ERC20.sol";
import {SafeTransferLib} from "../../open-zeppelin/utils/SafeTransferLib.sol";
import {IVault} from "../interfaces/IVault.sol";
import {EtherUtils} from "../utils/EtherUtils.sol";
import {IVault} from "../interfaces/IVault.sol";
import {IbalancerQueries} from "../interfaces/IbalancerQueries.sol";
import  "../../open-zeppelin/utils/ReentrancyGuard.sol";   

abstract contract ABalancer is EtherUtils, ReentrancyGuard {
    using SafeTransferLib for ERC20;

    // Base mainnet address of IMO.
    address internal IMO = 	0x0f1D1b7abAeC1Df25f2C4Db751686FC5233f6D3f;

    // Base mainnet address balanlcer vault.
    address public vault = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    // Base mainnet id for balancer IMO-WETH pool.
    bytes32 public poolId = 0x7120fd744ca7b45517243ce095c568fd88661c66000200000000000000000179;
    //Base mainnet Address of Balancer Queries 
    address public balancerQueries = 0x300Ab2038EAc391f26D9F895dc61F8F66a548833;

    /// @notice Emitted when the Balancer vault address is updated.
    /// @param newVault The address of the new Balancer vault.
    event SetBalancerVault(address newVault);

    /// @notice Emitted when the Balancer pool ID is updated.
    /// @param newPoolId The new pool ID.
    event SetBalancerPoolId(bytes32 newPoolId);

    event SetImoAddress(address newAddress);

     /// @notice Sets a new address for the IMO address.
    /// @param _newAddress The address of the new IMO Token.
    function setImoAddress(address _newAddress) external onlyOwner {
        IMO = _newAddress;

        emit SetImoAddress(_newAddress);
    }

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

    function setBalancerQueries(address _balancerQueries) external onlyOwner {
        balancerQueries = _balancerQueries;
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
    function ethToImo(uint256 amount, uint256 imoOutMin, address sender, address receiver) public payable returns (uint256 amountOutCalculated) {
        IVault.SingleSwap memory params = IVault.SingleSwap({
            poolId: poolId,
            kind: 0, // exact input, output given
            assetIn: address(0), //eth native adress
            assetOut: IMO,
            amount: amount, // Amount to swap
            userData: ""
        });

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: sender, // Funds are taken from this contract
            recipient: receiver, // Swapped tokens are sent back to this contract
            fromInternalBalance: false, // Don't take funds from contract LPs (since there's none)
            toInternalBalance: false // Don't LP with swapped funds
        });

        amountOutCalculated = IVault(vault).swap(params, funds, imoOutMin, block.timestamp);
    }

    function queryJoinImoPool(uint256 EthAmount, uint256 ImoAmount, address sender, address receiver) public nonReentrant returns (uint256 amountOutCalculated) {
        //ETH address for the pool is 0 (given pool is denomiated in ETH)
        IbalancerQueries.JoinPoolRequest memory request = IbalancerQueries.JoinPoolRequest({
            assets: [IMO, address(0)],
            maxAmountsIn: [ImoAmount, EthAmount],
            userData: "",
            fromInternalBalance: false
        });

        IbalancerQueries.FundManagement memory funds = IbalancerQueries.FundManagement({
            sender: sender,
            recipient: payable(receiver),
            fromInternalBalance: false,
            toInternalBalance: false
        });

        (amountOutCalculated,) = IbalancerQueries(balancerQueries).queryJoin(poolId, sender, receiver, request);
    }

    function joinImoPool(uint256 EthAmount, uint256 ImoAmount, address sender, address receiver) public payable nonReentrant {
        //ETH address for the pool is 0 (given pool is denomiated in ETH)
        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest({
            assets: [IMO, address(0)],
            maxAmountsIn: [ImoAmount, EthAmount],
            userData: "",
            fromInternalBalance: false
        });

        IVault.FundManagement memory funds = IVault.FundManagement({
            sender: sender,
            recipient: receiver,
            fromInternalBalance: false,
            toInternalBalance: false
        });

        IVault(vault).joinPool(poolId, sender, receiver, request);
    }  
}