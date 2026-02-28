// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";
import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";
import {IC3UUIDKeeper} from "@c3caller/uuid/IC3UUIDKeeper.sol";
import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";
import {IC3Caller} from "@c3caller/IC3Caller.sol";
import {IC3Governor} from "@c3caller/gov/IC3Governor.sol";
import {ICTMERC20} from "@c3caller/token/ICTMERC20.sol";

import {ICTM} from "../build/token/ctm/CTM.sol";

contract InitializeProtocol is Script, Config {
    using Strings for address;

    function run() public {
        _loadConfig("./config/initialize.toml", false);

        bool daoLocal = vm.envOr("DAO_LOCAL", false);

        address _uuidKeeper = config.get("uuidKeeper").toAddress();
        address _dappManager = config.get("dappManager").toAddress();
        address _c3caller = config.get("c3caller").toAddress();
        address _c3governor = config.get("c3governor").toAddress();
        address _ctm = config.get("ctm").toAddress();
        address _usdc = config.get("usdc").toAddress();
        address mpc = config.get("mpc").toAddress();

        string memory dappKey_c3gov_u = config.get("dappKey_c3gov_u").toString();
        string memory dappKey_ctm = config.get("dappKey_ctm").toString();
        string memory metadata_c3gov = config.get("metadata_c3gov").toString();
        string memory metadata_ctm = config.get("metadata_ctm").toString();

        IC3DAppManager dappManager = IC3DAppManager(_dappManager);
        IC3Caller c3caller = IC3Caller(_c3caller);
        IC3Governor c3governor = IC3Governor(_c3governor);
        ICTMERC20 ctm = ICTMERC20(_ctm);

        string memory c3governor_s = _c3governor.toChecksumHexString();
        string memory ctm_s = _ctm.toChecksumHexString();

        vm.startBroadcast();

        // 0. Apply admin as gov in protocol contracts
        IC3GovClient(_uuidKeeper).applyGov();
        IC3GovClient(_dappManager).applyGov();
        IC3GovClient(_c3caller).applyGov();

        // 1. Initialize UUID Keeper and DApp Manager
        IC3GovClient(_uuidKeeper).setC3Caller(_c3caller);
        IC3GovClient(_dappManager).setC3Caller(_c3caller);

        // 2. Set governance change delays for C3Governor & CTM to zero
        IC3GovernDApp(_c3governor).setDelay(0);
        IC3GovernDApp(_ctm).setDelay(0);

        // 3. Add MPC
        c3caller.addMPC(mpc);

        // 4. Activate C3Caller chain IDs
        c3caller.activateChainID("1"); // Ethereum
        c3caller.activateChainID("59144"); // Linea
        // c3caller.activateChainID("11155111"); // Ethereum Sepolia
        // c3caller.activateChainID("59141");    // Linea Sepolia

        if (daoLocal) {
            // 5. Set peer in C3Governor
            c3governor.setPeer("1", c3governor_s); // Ethereum
            // c3governor.setPeer("11155111", c3governor_s); // Ethereum Sepolia
        }

        // 5.5: Set peer in CTM
        ctm.setPeer("1", ctm_s); // Ethereum
        ctm.setPeer("59144", ctm_s); // Linea
        // ctm.setPeer("11155111", ctm_s); // Sepolia
        // ctm.setPeer("59141", ctm_s);    // Linea Sepolia

        // 6. Set Fee Config in DApp Manager
        dappManager.setFeeConfig(_usdc, 1000, 3500e6); // 0.001 USDC per byte, 3500 USDC per ether
        dappManager.setFeeMinimumDeposit(_usdc, 10e6); // 10 USDC minimum deposit

        // 6.5: Approve DApp Manager to spend 20 USDC (10 USDC x2)
        IERC20(_usdc).approve(_dappManager, 20e6);

        // 7. Create C3Governor & CTM C3DApps
        uint256 dapp_id_c3gov = dappManager.initDAppConfig(dappKey_c3gov_u, _usdc, metadata_c3gov);
        uint256 dapp_id_ctm = dappManager.initDAppConfig(dappKey_ctm, _usdc, metadata_ctm);

        // 8. Add DApp addresses for C3Governor and CTM
        dappManager.setDAppAddr(dapp_id_c3gov, _c3governor, true);
        dappManager.setDAppAddr(dapp_id_ctm, _ctm, true);

        if (!daoLocal) {
            console.log("DAO is not local: setting protocol contracts' gov to c3governor.");
            // 9. Change gov in protocol contracts to C3Governor
            IC3GovClient(_uuidKeeper).changeGov(_c3governor);
            IC3GovClient(_dappManager).changeGov(_c3governor);
            IC3GovClient(_c3caller).changeGov(_c3governor);

            // 10. Apply gov from C3Governor contract
            c3governor.applySelfAsGov(_uuidKeeper);
            c3governor.applySelfAsGov(_dappManager);
            c3governor.applySelfAsGov(_c3caller);
        } else {
            console.log("DAO is local: not setting protocol contracts' gov.");
        }

        vm.stopBroadcast();
    }
}
