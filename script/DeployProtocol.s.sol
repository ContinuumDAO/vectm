// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {C3CallerProxy} from "@c3caller/utils/C3CallerProxy.sol";
import {C3UUIDKeeperUpgradeable} from "@c3caller/upgradeable/uuid/C3UUIDKeeperUpgradeable.sol";
import {
    C3DAppManagerUpgradeable,
    IC3DAppManagerUpgradeable
} from "@c3caller/upgradeable/dapp/C3DAppManagerUpgradeable.sol";
import {C3CallerUpgradeable} from "@c3caller/upgradeable/C3CallerUpgradeable.sol";
import {C3GovernorUpgradeable} from "@c3caller/upgradeable/gov/C3GovernorUpgradeable.sol";

import {C3UUIDKeeper} from "@c3caller/uuid/C3UUIDKeeper.sol";
import {C3DAppManager, IC3DAppManager} from "@c3caller/dapp/C3DAppManager.sol";
import {C3Caller} from "@c3caller/C3Caller.sol";
import {C3Governor} from "@c3caller/gov/C3Governor.sol";
import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";

import {CTMMintable} from "../build/token/ctm/CTMMintable.sol";
import {CTM} from "../build/token/ctm/CTM.sol";

contract DeployProtocol is Script, Config {
    function run() public {
        _loadConfig("./config/deploy.toml", false);

        address admin = config.get("admin").toAddress();
        string memory dappKey_c3gov_u = config.get("dappKey_c3gov_u").toString();

        vm.startBroadcast();

        // Deploy UUID Keeper
        C3UUIDKeeperUpgradeable uuidKeeperImpl = new C3UUIDKeeperUpgradeable();
        bytes memory uuidKeeperInit = abi.encodeWithSelector(C3UUIDKeeperUpgradeable.initialize.selector);
        C3CallerProxy uuidKeeperProxy = new C3CallerProxy(address(uuidKeeperImpl), uuidKeeperInit);
        address uuidKeeper_u = address(uuidKeeperProxy);

        // Deploy DApp Manager
        C3DAppManagerUpgradeable dappManagerImpl = new C3DAppManagerUpgradeable();
        bytes memory dappManagerInit = abi.encodeWithSelector(C3DAppManagerUpgradeable.initialize.selector);
        C3CallerProxy dappManagerProxy = new C3CallerProxy(address(dappManagerImpl), dappManagerInit);
        address dappManager_u = address(dappManagerProxy);

        // Deploy core C3Caller
        C3CallerUpgradeable c3callerImpl = new C3CallerUpgradeable();
        bytes memory c3callerInit =
            abi.encodeWithSelector(C3CallerUpgradeable.initialize.selector, uuidKeeper_u, dappManager_u);
        C3CallerProxy c3callerProxy = new C3CallerProxy(address(c3callerImpl), c3callerInit);
        address c3caller_u = address(c3callerProxy);

        uint256 dappID_c3gov_u = IC3DAppManagerUpgradeable(dappManager_u).deriveDAppID(admin, dappKey_c3gov_u);

        // Deploy C3Governor
        C3GovernorUpgradeable c3governorImpl = new C3GovernorUpgradeable();
        bytes memory c3governorInit =
            abi.encodeWithSelector(C3GovernorUpgradeable.initialize.selector, admin, c3caller_u, dappID_c3gov_u);
        C3CallerProxy c3governorProxy = new C3CallerProxy(address(c3governorImpl), c3governorInit);
        address c3governor_u = address(c3governorProxy);

        IC3GovClient(uuidKeeper_u).changeGov(admin);
        IC3GovClient(dappManager_u).changeGov(admin);
        IC3GovClient(c3caller_u).changeGov(admin);

        vm.stopBroadcast();

        console.log("C3UUIDKeeperUpgradeable:", uuidKeeper_u);
        console.log("C3DAppManagerUpgradeable:", dappManager_u);
        console.log("C3CallerUpgradeable:", c3caller_u);
        console.log("C3GovernorUpgradeable:", c3governor_u);
    }
}
