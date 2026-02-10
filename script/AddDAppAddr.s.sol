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

    string dappManagerKey = string.concat("DAPP_MANAGER_", vm.toString(block.chainid));

    function run() public {
        try vm.envAddress("DEPLOYER") returns (address _deployer) {
            deployer = _deployer;
        } catch {
            revert("DEPLOYER not defined");
        }

        try vm.envAddress(dappManagerKey) returns (address _dappManagerAddr) {
            dappManagerAddr = _dappManagerAddr;
        } catch {
            revert(string.concat(dappManagerKey, " not defined"));
        }

        try vm.envUint("DAPP_ID_CTM") returns (uint256 _dappID) {
            dappID = _dappID;
        } catch {
            revert("DAPP_ID_CTM not defined");
        }

        try vm.envAddress("CTM") returns (address _ctm) {
            ctm = _ctm;
        } catch {
            revert("CTM not defined");
        }

        vm.startBroadcast(deployer);

        console.log("Adding CTM address in DApp Manager...");

        IC3DAppManager(dappManagerAddr).setDAppAddr(dappID, ctm, true);

        console.log("CTM address added.");

        vm.stopBroadcast();
    }
}
