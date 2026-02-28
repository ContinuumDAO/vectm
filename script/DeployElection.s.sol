// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

contract DAOCommittee {
    error OnlyGov();

    mapping(string => bool) public isCommitteeMember;
    string[] public allCommitteeMembers;
    address public gov;

    modifier onlyGov() {
        if (msg.sender != gov) {
            revert OnlyGov();
        }
        _;
    }

    constructor(address _gov) {
        gov = _gov;
    }

    function setGov(address _newGov) external onlyGov {
        gov = _newGov;
    }

    function addToCommittee(string memory _handle) external onlyGov {
        isCommitteeMember[_handle] = true;
        allCommitteeMembers.push(_handle);
    }
}

contract DeployElection is Script {
    function run() public {
        address dao = 0x9250E566656C9f35FAaA87a7873fb8ADE5A9BF02;

        vm.startBroadcast();
        DAOCommittee daoCommittee = new DAOCommittee(dao);
        vm.stopBroadcast();
        console.log("Election deployed to: ", address(daoCommittee));
    }
}
