// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DeterministicDeployments is Script {
    function run() public {
        address deployer = 0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F;
        uint256 startingNonce = 149;

        for (uint256 i = startingNonce; i < startingNonce + 128; i++) {
            address create_i = vm.computeCreateAddress(deployer, i);
            console.log("Nonce = ", i);
            console.log("Create Address: ", create_i);
        }
    }
}
