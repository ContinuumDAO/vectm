// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {CTMMintable} from "../src/token/CTMMintable.sol";

contract DeployCTMMintable is Script {
    using Strings for address;

    address deployer;
    address c3caller;
    address dappManager;
    uint256 dappID;

    function run() public {
        try vm.envAddress("DEPLOYER") returns (address _deployer) {
            deployer = _deployer;
        } catch {
            revert("DEPLOYER not defined");
        }

        try vm.envAddress("C3CALLER_421614") returns (address _c3caller) {
            c3caller = _c3caller;
        } catch {
            revert("C3CALLER_421614 not defined");
        }

        try vm.envAddress("DAPP_MANAGER_421614") returns (address _dappManager) {
            dappManager = _dappManager;
        } catch {
            revert("DAPP_MANAGER_421614 not defined");
        }

        try vm.envUint("DAPP_ID_CTM") returns (uint256 _dappID) {
            dappID = _dappID;
        } catch {
            revert("DAPP_ID_CTM not defined");
        }

        vm.startBroadcast();

        console.log("Deploying CTM Token...");

        CTMMintable ctmMintable = new CTMMintable(c3caller, dappID, dappManager);

        console.log("CTM Token deployed at:", address(ctmMintable));

        console.log("Settings peers for arbitrum-sepolia...");
        ctmMintable.setPeer("421614", address(ctmMintable).toHexString());

        console.log("Setting peers for bsc-testnet...");
        ctmMintable.setPeer("97", address(ctmMintable).toHexString());

        console.log("Setting peers for ethereum-sepolia...");
        ctmMintable.setPeer("11155111", address(ctmMintable).toHexString());

        vm.stopBroadcast();
    }
}
