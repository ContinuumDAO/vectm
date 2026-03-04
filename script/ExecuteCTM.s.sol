// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IC3Caller} from "@c3caller/IC3Caller.sol";
import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";
import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";
import {IC3Governor} from "@c3caller/gov/IC3Governor.sol";
import {ICTMERC20} from "@c3caller/token/ICTMERC20.sol";

contract ExecuteCTM is Script {
    function run() public {
        address c3caller = 0x2f925D6512b2BbB00f5a36d8B18E01fcf35F7Dc7;
        address ctm = 0x2026027054F5beBCEB650aBD62dC623e327658e7;
        uint256 ctm_id = 26243786160252405427302909576549313777876500874080323496247859302443561356480;
        string memory fromStr = "0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F";
        string memory toStr = "0xD836F55ecc0EE45a852460b4243001e642eCca86";
        uint256 amount = 20168947499999000000000000;

        bytes memory c3receiveData = abi.encodeWithSelector(ICTMERC20.c3receive.selector, fromStr, toStr, amount);

        bytes32 uuid = 0x60AB784B5306BB188AFC131052ECEC8F3FE77DF5C68D196D76E14E9174214DA6;
        string memory fromChainID = "1";
        string memory sourceTxHash = "0x635b8dacba0fd85afdbd5f9a45045006e856f6f73bbbe67901a6844a97233d3a";
        string memory fallbackTo = "0x2026027054F5beBCEB650aBD62dC623e327658e7";
        IC3Caller.C3EvmMessage memory message =
            IC3Caller.C3EvmMessage(uuid, ctm, fromChainID, sourceTxHash, fallbackTo, c3receiveData);

        vm.startBroadcast();

        IC3Caller(c3caller).execute(ctm_id, message);

        vm.stopBroadcast();
    }
}
