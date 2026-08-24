// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {VotingEscrow} from "../../src/token/VotingEscrow.sol";

/// @dev Test-only implementation that retains `initialize` for fresh proxy deployments.
/// Production VotingEscrow omits `initialize` to save bytecode on upgrade implementations.
contract VotingEscrowDeploy is VotingEscrow {
    function initialize(
        address token_addr,
        address _governor,
        address _nodeProperties,
        address _rewards,
        string memory base_uri
    ) external initializer {
        __UUPSUpgradeable_init();
        token = token_addr;
        baseURI = base_uri;
        point_history[0].blk = block.number;
        point_history[0].ts = block.timestamp;
        minimumLock = 1 ether;

        governor = _governor;
        nodeProperties = _nodeProperties;
        rewards = _rewards;
        treasury = _governor;

        supportedInterfaces[ERC165_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_INTERFACE_ID] = true;
        supportedInterfaces[ERC721_METADATA_INTERFACE_ID] = true;
        supportedInterfaces[VOTES_INTERFACE_ID] = true;
        supportedInterfaces[ERC6372_INTERFACE_ID] = true;

        _entered_state = 1;

        emit Transfer(address(0), address(this), tokenId);
        emit Transfer(address(this), address(0), tokenId);
    }
}
