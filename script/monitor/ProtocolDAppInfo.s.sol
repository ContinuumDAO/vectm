// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {Config} from "forge-std/Config.sol";
import {console} from "forge-std/console.sol";

import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";

contract ProtocolDAppInfo is Script, Config {
    mapping(address => string) private _labels;

    function run() public {
        _loadConfig("./config/deployments.toml", false);

        address creator = config.get("admin").toAddress();
        address dappManager = config.get("dappManager").toAddress();
        address usdc = config.get("usdc").toAddress();
        address c3governor = config.get("c3governor").toAddress();
        address ctm = config.get("ctm").toAddress();

        _labels[c3governor] = string.concat("C3Governor_", vm.toString(block.chainid));
        _labels[creator] = "Admin";
        _labels[usdc] = "USDC";
        _labels[ctm] = "CTM";

        if (block.chainid == 59144) {
            address dao = config.get("dao").toAddress();
            _labels[dao] = "ContinuumDAO";
        }

        IC3DAppManager _dappManager = IC3DAppManager(dappManager);
        uint256 discountDenom = _dappManager.DISCOUNT_DENOMINATOR();

        _logDAppInfo(_dappManager, creator, config.get("dappKey_c3gov_u").toString(), discountDenom, true);
        _logDAppInfo(_dappManager, creator, config.get("dappKey_ctm").toString(), discountDenom, false);
    }

    function _logDAppInfo(
        IC3DAppManager dappManager,
        address creator,
        string memory dappKey,
        uint256 discountDenom,
        bool isC3Gov
    ) internal view {
        uint256 dappID = dappManager.deriveDAppID(creator, dappKey);
        address[] memory dappAddrs = dappManager.getAllDAppAddrs(dappID);
        (address admin, address feeToken, uint256 discount, uint256 lastUpdated, string memory metadata) =
            dappManager.dappConfig(dappID);

        uint256 reserves = dappManager.dappStakePool(dappID, feeToken);

        string memory tag = isC3Gov ? "C3Governor" : "CTM";
        console.log(string.concat(tag, " DApp:"));
        console.log(string.concat("DApp ID ", tag, ":"), dappID);
        console.log(string.concat("Admin ", tag, ":"), _labels[admin]);
        console.log(string.concat("Fee Token ", tag, ":"), _labels[feeToken]);
        console.log(string.concat("Discount % ", tag, ":"), discount / discountDenom * 100);
        console.log(string.concat("Last Updated ", tag, ":"), lastUpdated);
        console.log(string.concat("Metadata ", tag, ":"), metadata);
        console.log("Fee Token Reserves:", string.concat(vm.toString(reserves), " ", _labels[feeToken]));

        for (uint256 i = 0; i < dappAddrs.length; i++) {
            console.log(string.concat("DApp Address ", tag, " ", vm.toString(i), ":"));
            console.log(_labels[dappAddrs[i]]);
        }

        console.log("-----");
    }
}
