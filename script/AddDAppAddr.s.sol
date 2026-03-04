// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {CTM} from "../src/token/CTM.sol";

import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";

contract AddDAppAddr is Script {
    using Strings for address;

    address deployer;
    address dappManagerAddr;
    uint256 dappID;
    address ctm;

    function run() public {
        try vm.envAddress("DEPLOYER") returns (address _deployer) {
            deployer = _deployer;
        } catch {
            revert("DEPLOYER not defined");
        }

        try vm.envAddress("DAPP_MANAGER") returns (address _dappManagerAddr) {
            dappManagerAddr = _dappManagerAddr;
        } catch {
            revert("DAPP_MANAGER not defined");
        }

        try vm.envAddress("CTM") returns (address _ctm) {
            ctm = _ctm;
        } catch {
            revert("CTM not defined");
        }

        string memory toml = vm.readFile(string.concat(vm.projectRoot(), "/deployments.toml"));
        string memory chainKey = vm.toString(block.chainid);
        string memory chainPath = string.concat(".[\"", chainKey, "\"]");
        string memory dappKey = abi.decode(vm.parseToml(toml, string.concat(chainPath, ".dapp_key")), (string));

        dappID = IC3DAppManager(dappManagerAddr).deriveDAppID(deployer, dappKey);

        vm.startBroadcast();

        console.log("Adding CTM address in DApp Manager...");

        IC3DAppManager(dappManagerAddr).setDAppAddr(dappID, ctm, true);

        console.log("CTM address added.");

        vm.stopBroadcast();
    }
}
