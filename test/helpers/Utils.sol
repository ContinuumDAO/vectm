// SPDX-License-Identifier: GPL-3.0-or-later

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
}
