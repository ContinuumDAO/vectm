// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {C3CallerProxy} from "@c3caller/utils/C3CallerProxy.sol";

import {VotingEscrowProxy} from "../../build/utils/VotingEscrowProxy.sol";

contract ProtocolProxies is Script, Config {
    function run() public {
        _loadConfig("./config/deployments.toml", false);

        address uuidKeeper = config.get("uuidKeeper").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        address c3caller = config.get("c3caller").toAddress();
        address c3governor = config.get("c3governor").toAddress();

        address uuidKeeperImpl = config.get("uuidKeeperImpl").toAddress();
        address dappManagerImpl = config.get("dappManagerImpl").toAddress();
        address c3callerImpl = config.get("c3callerImpl").toAddress();
        address c3governorImpl = config.get("c3governorImpl").toAddress();

        address _uuidKeeperImpl = C3CallerProxy(payable(uuidKeeper)).getImplementation();
        address _dappManagerImpl = C3CallerProxy(payable(dappManager)).getImplementation();
        address _c3callerImpl = C3CallerProxy(payable(c3caller)).getImplementation();
        address _c3governorImpl = C3CallerProxy(payable(c3governor)).getImplementation();

        if (_uuidKeeperImpl == uuidKeeperImpl) {
            console.log("C3UUIDKeeper Implementation correct.");
        } else {
            console.log("WARNING: C3UUIDKeeper Implementation incorrect.");
            console.log("Expected:", uuidKeeperImpl);
            console.log("Actual:", _uuidKeeperImpl);
        }

        if (_dappManagerImpl == dappManagerImpl) {
            console.log("C3DAppManager Implementation correct.");
        } else {
            console.log("WARNING: C3DAppManager Implementation incorrect.");
            console.log("Expected:", dappManagerImpl);
            console.log("Actual:", _dappManagerImpl);
        }

        if (_c3callerImpl == c3callerImpl) {
            console.log("C3Caller Implementation correct.");
        } else {
            console.log("WARNING: C3Caller Implementation incorrect.");
            console.log("Expected:", c3callerImpl);
            console.log("Actual:", _c3callerImpl);
        }

        if (_c3governorImpl == c3governorImpl) {
            console.log("C3Governor Implementation correct.");
        } else {
            console.log("WARNING: C3Governor Implementation incorrect.");
            console.log("Expected:", c3governorImpl);
            console.log("Actual:", _c3governorImpl);
        }

        if (block.chainid == 59144) {
            address ve = config.get("ve").toAddress();
            address veImpl = config.get("veImpl").toAddress();
            address _veImpl = VotingEscrowProxy(payable(ve)).getImplementation();
            if (_veImpl == veImpl) {
                console.log("VotingEscrow Implementation correct.");
            } else {
                console.log("WARNING: VotingEscrow Implementation incorrect.");
                console.log("Expected:", veImpl);
                console.log("Actual:", _veImpl);
            }
        }
    }
}
