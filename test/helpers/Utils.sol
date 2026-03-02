// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {VotingEscrowProxy} from "../../src/utils/VotingEscrowProxy.sol";

contract Utils is Test {
    function getRevert(bytes calldata _payload) external pure returns (bytes memory) {
        return (abi.decode(_payload[4:], (bytes)));
    }

    function _deployProxy(address implementation, bytes memory _data) internal returns (address proxy) {
        proxy = address(new VotingEscrowProxy(implementation, _data));
    }

    // ============ HELPER FUNCTIONS FOR STRESS TESTS ============

    function _generateLargeStringArray(uint256 size) internal pure returns (string[] memory) {
        string[] memory array = new string[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = string(abi.encodePacked("string_", i, "_with_many_characters_to_test_string_handling"));
        }
        return array;
    }

    function _generateLargeAddressArray(uint256 size) internal pure returns (address[] memory) {
        address[] memory array = new address[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = address(uint160(i + 1));
        }
        return array;
    }

    function _generateLargeBoolArray(uint256 size) internal pure returns (bool[] memory) {
        bool[] memory array = new bool[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = i % 2 == 0;
        }
        return array;
    }

    function _generateLargeUintArray(uint256 size) internal pure returns (uint256[] memory) {
        uint256[] memory array = new uint256[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = i * 123_456_789;
        }
        return array;
    }

    function _generateLargeBytes(uint256 size) internal pure returns (bytes memory) {
        bytes memory data = new bytes(size);
        for (uint256 i = 0; i < size; i++) {
            data[i] = bytes1(uint8(i % 256));
        }
        return data;
    }

    function _generateLargeBytesArray(uint256 size) internal pure returns (bytes[] memory) {
        bytes[] memory array = new bytes[](size);
        for (uint256 i = 0; i < size; i++) {
            array[i] = _generateLargeBytes(100 + i);
        }
        return array;
    }

    /// @notice Predicts the address of a contract that will be deployed
    ///         by `deployer` with the given `nonce` using the normal CREATE opcode.
    /// @dev Handles the full RLP encoding of [deployer, nonce] correctly.
    function predictCREATEAddress(address deployer, uint256 nonce) public pure returns (address) {
        bytes memory data;
        if (nonce == 0) {
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(0x80));
        } else if (nonce < 0x80) {
            // nonce 1 to 127
            data = abi.encodePacked(bytes1(0xd6), bytes1(0x94), deployer, bytes1(uint8(nonce)));
        } else if (nonce <= 0xff) {
            data = abi.encodePacked(bytes1(0xd7), bytes1(0x94), deployer, bytes1(0x81), uint8(nonce));
        } else if (nonce <= 0xffff) {
            data = abi.encodePacked(bytes1(0xd8), bytes1(0x94), deployer, bytes1(0x82), uint16(nonce));
        } else if (nonce <= 0xffffff) {
            data = abi.encodePacked(bytes1(0xd9), bytes1(0x94), deployer, bytes1(0x83), uint24(nonce));
        } else {
            // covers up to 2^32-1 (more than enough; >2^32 txs is unrealistic)
            data = abi.encodePacked(bytes1(0xda), bytes1(0x94), deployer, bytes1(0x84), uint32(nonce));
        }

        return address(uint160(uint256(keccak256(data))));
    }
}
