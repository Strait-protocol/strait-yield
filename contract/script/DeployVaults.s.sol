// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {StraitYieldVault} from "../src/StraitYieldVault.sol";

/// Deploys the two separate pools (README §6: USDC and VUSD are never
/// bridged/converted within the vault) onto Hemi (README §6 deployment
/// decision). Fill in the real USDC/VUSD token addresses on Hemi before running.
contract DeployVaults is Script {
    function run() external {
        address usdc = vm.envAddress("USDC_ADDRESS");
        address vusd = vm.envAddress("VUSD_ADDRESS");
        address owner = vm.envAddress("VAULT_OWNER");

        vm.startBroadcast();

        StraitYieldVault usdcVault = new StraitYieldVault(IERC20(usdc), "Strait Yield USDC", "syUSDC", owner);
        StraitYieldVault vusdVault = new StraitYieldVault(IERC20(vusd), "Strait Yield VUSD", "syVUSD", owner);

        vm.stopBroadcast();

        console2.log("StraitYieldVault (USDC):", address(usdcVault));
        console2.log("StraitYieldVault (VUSD):", address(vusdVault));
    }
}
