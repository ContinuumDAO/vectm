// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {IGovernor} from "build/CTMDAOGovernor.sol";
import {IVotingEscrow} from "build/VotingEscrow.sol";

contract Upgrade is Script {
    address governorAddr = 0x1271D5C10663a0e34aFD1Ae5362EB9E29b1E3d97;
    IGovernor governor = IGovernor(governorAddr);

    address veAddr = 0xAF0D3b20ac92e6825014549bB3FA937b3BF5731A;
    IVotingEscrow ve = IVotingEscrow(veAddr);

    address newDeployedVeImpl = 0xc46B149bC1977a437180B8FF3e91166Af5222962;

    function run() external {

        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");

        address token = ve.token();
        string memory URI = ve.baseURI();

        bytes memory initializerDataV2 = abi.encodeWithSignature(
            "initialize(address,string)",
            token,
            URI
        );

        vm.startBroadcast(senderPrivateKey);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        targets[0] = veAddr;
        values[0] = 0;
        calldatas[0] = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            newDeployedVeImpl,
            initializerDataV2
        );
        string memory description = "Proposal #3: Upgrade veCTM to fix Merge bug (re-attempt)";

        governor.propose(targets, values, calldatas, description);

        vm.stopBroadcast();
    }
}