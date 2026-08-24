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
        address ctm = 0x7581696b0ED142f6534E5797baaABBb9a1b27086;
        uint256 ctm_id = 26243786160252405427302909576549313777876500874080323496247859302443561356480;
        string memory fromStr = "0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F";
        string memory toStr = "0x4800F9f1dC1b6daCA841B71E0531F547D374168E";
        uint256 amount = 25000000000000000000000;

        bytes memory c3receiveData = abi.encodeWithSelector(ICTMERC20.c3receive.selector, fromStr, toStr, amount);

        bytes32 uuid = 0x03E7108146D1E55D87CF0F334C4FB0F5CE4155FC109C5BE87514BD99A23C865D;
        string memory fromChainID = "1";
        string memory sourceTxHash = "0x6ec89fad63c70f0d5691f38e46eddc1228ea5cfcce20ba4ea5c556dfbfa97c77";
        string memory fallbackTo = "0x7581696b0ED142f6534E5797baaABBb9a1b27086";
        IC3Caller.C3EvmMessage memory message =
            IC3Caller.C3EvmMessage(uuid, ctm, fromChainID, sourceTxHash, fallbackTo, c3receiveData);

        vm.startBroadcast();

        IC3Caller(c3caller).execute(ctm_id, message);

        vm.stopBroadcast();
    }
}
