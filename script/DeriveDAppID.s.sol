// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {C3DAppManager} from "@c3caller/dapp/C3DAppManager.sol";

contract DeriveDAppID is Script {

    address creator = 0xccc435AaBc481D4Af9da51E51Eb2a383Bce6791F;
    string dappKey = "v1.continuumdao.c3governor_u";

    function run() public {
        C3DAppManager dappManager = new C3DAppManager();

        uint256 dappID = dappManager.deriveDAppID(creator, dappKey);

        console.log("DApp ID:", dappID);
    }
}
