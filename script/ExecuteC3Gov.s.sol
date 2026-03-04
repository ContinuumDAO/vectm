// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {IC3Caller} from "@c3caller/IC3Caller.sol";
import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";
import {IC3GovClient} from "@c3caller/gov/IC3GovClient.sol";
import {IC3Governor} from "@c3caller/gov/IC3Governor.sol";

contract ExecuteC3Gov is Script {
    function run() public {
        address c3caller = 0x2f925D6512b2BbB00f5a36d8B18E01fcf35F7Dc7;
        address c3governor = 0x58B610a359c870E0fc941139821a51F5aa23f14E;
        address admin = 0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F;
        uint256 c3gov_id = 54841553903020218527075297192242923310195705512185382121058570035346596394010;

        uint256 c3govNonce = 605;
        uint256 c3govIndex = 0;
        string memory c3govTarget = "0x2f925D6512b2BbB00f5a36d8B18E01fcf35F7Dc7";
        string memory c3govExecChainId = "1";
        bytes memory c3govData = abi.encodeWithSelector(IC3GovClient.changeGov.selector, admin);
        bytes memory receiveParamsData = abi.encodeWithSelector(
            IC3Governor.receiveParams.selector, c3govNonce, c3govIndex, c3govTarget, c3govExecChainId, c3govData
        );

        bytes32 uuid = keccak256("c3caller_changeGov");
        string memory fromChainID = "59144";
        string memory sourceTxHash = "0x0101010101010101010101010101010101010101010101010101010101010101";
        string memory fallbackTo = "0x58B610a359c870E0fc941139821a51F5aa23f14E";
        IC3Caller.C3EvmMessage memory message =
            IC3Caller.C3EvmMessage(uuid, c3governor, fromChainID, sourceTxHash, fallbackTo, receiveParamsData);

        vm.startBroadcast();

        IC3Caller(c3caller).execute(c3gov_id, message);

        vm.stopBroadcast();
    }
}
