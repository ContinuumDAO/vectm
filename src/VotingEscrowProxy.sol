// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {TransparentUpgradeableProxy} from "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";


contract VotingEscrowProxy is TransparentUpgradeableProxy {
    constructor(address _logic, address initialOwner) TransparentUpgradeableProxy(_logic, initialOwner, "") {}

    function admin() public returns (address) {
        return _proxyAdmin();
    }

    receive() payable external {
        _fallback();
    }
}