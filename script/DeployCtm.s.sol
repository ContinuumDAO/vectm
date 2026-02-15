// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";


import {CTM} from "../src/token/CTM.sol";
import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";


contract DeployCtm is Script {
    address deployer;
    uint256 chainID;
    address dappManager;
    uint256 dappID;
    string dappKey;

    function run() public {
        try vm.envAddress("DEPLOYER") returns (address _deployer) {
            deployer = _deployer;
        } catch {
            revert("DEPLOYER not defined");
        }

        try vm.envUint("CHAIN_ID") returns (uint256 _chainID) {
            chainID = _chainID;
        } catch {
            revert("CHAIN_ID not defined");
        }

        try vm.envString("DAPP_KEY") returns (string memory _dappKey) {
            dappKey = _dappKey;
        } catch {
            revert("DAPP_KEY not defined");
        }

        string memory toml = vm.readFile(string.concat(vm.projectRoot(), "/deployments.toml"));
        string memory chainKey = vm.toString(chainID);
        // JSONPath requires bracket notation for numeric keys (e.g. .["11155111"].address.c3caller)
        string memory chainPath = string.concat(".[\"", chainKey, "\"]");
        address c3caller = abi.decode(vm.parseToml(toml, string.concat(chainPath, ".address.c3caller")), (address));
        dappManager = abi.decode(vm.parseToml(toml, string.concat(chainPath, ".address.dappManager")), (address));

        vm.startBroadcast();

        console.log("Deriving DApp ID...");

        dappID = IC3DAppManager(dappManager).deriveDAppID(deployer, dappKey);

        console.log("Deploying CTM Token...");

        CTM ctm = new CTM(c3caller, dappID, dappManager);
        console.log("CTM deployed at:", address(ctm));

        _setPeersForAllChains(toml, ctm);

        vm.stopBroadcast();
    }

    function _setPeersForAllChains(string memory toml, CTM ctm) internal {
        string[] memory chainKeys = vm.parseTomlKeys(toml, ".");
        string memory peerAddr = vm.toString(address(ctm));
        for (uint256 i = 0; i < chainKeys.length; i++) {
            string memory chainId = chainKeys[i];
            // Skip non-numeric keys (e.g. comment or section like "address" without parent)
            if (_isNumericChainId(chainId)) {
                console.log("Setting peer for chainId:", chainId);
                ctm.setPeer(chainId, peerAddr);
            }
        }
    }

    function _isNumericChainId(string memory s) internal pure returns (bool) {
        if (bytes(s).length == 0) return false;
        for (uint256 i = 0; i < bytes(s).length; i++) {
            uint8 c = uint8(bytes(s)[i]);
            if (c < 48 || c > 57) return false; // not '0'-'9'
        }
        return true;
    }
}
