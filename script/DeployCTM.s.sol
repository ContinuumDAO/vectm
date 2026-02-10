// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {CTM} from "../src/token/CTM.sol";

contract DeployCTM is Script {
    using Strings for address;

    address deployer;
    address c3caller;
    uint256 dappID;

    string c3callerKey = string.concat("C3CALLER_", vm.toString(block.chainid));

    function run() public {
        try vm.envAddress("DEPLOYER") returns (address _deployer) {
            deployer = _deployer;
        } catch {
            revert("DEPLOYER not defined");
        }

        try vm.envAddress(c3callerKey) returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert(string.concat(c3callerKey, " not defined"));
        }

        try vm.envUint("DAPP_ID_CTM") returns (uint256 _dappID) {
            dappID = _dappID;
        } catch {
            revert("DAPP_ID_CTM not defined");
        }

        vm.startBroadcast();

        console.log("Deploying CTM Token...");

        CTM ctm = new CTM(c3caller, dappID);

        console.log("CTM Token deployed at:", address(ctm));

        console.log("Settings peers for arbitrum-sepolia...");
        ctm.setPeer("421614", address(ctm).toHexString());

        console.log("Setting peers for bsc-testnet...");
        ctm.setPeer("97", address(ctm).toHexString());

        console.log("Setting peers for ethereum-sepolia...");
        ctm.setPeer("11155111", address(ctm).toHexString());

        vm.stopBroadcast();
    }
}
