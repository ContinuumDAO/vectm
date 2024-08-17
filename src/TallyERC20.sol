// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IVotingEscrow {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function getPastTotalSupply(uint256 timepoint) external view returns (uint256);
    function getVotes(address account) external view returns (uint256);
    function getPastVotes(address account, uint256 timepoint) external view returns (uint256);
    function delegates(address account) external view returns (address);
}


contract TallyERC20 {
    address ve = 0xD1E59F3ba753947bae4A9D261a353D86734FA53d; // VotingEscrow on ETH Sepolia

    function getVotes(address account) external  returns (uint256) {
        bytes memory callHash = abi.encodeWithSignature("getVotes(address)",account);
        (bool success, bytes memory result) = ve.call(callHash);
        (uint256 _getVotesRes) = abi.decode(result, (uint256));
        return _getVotesRes;
    }

    function getPastVotes(address account, uint256 timepoint) external  returns (uint256) {
        bytes memory callHash = abi.encodeWithSignature("getPastVotes(address)",account);
        (bool success, bytes memory result) = ve.call(callHash);
        (uint256 _getPastVotesRes) = abi.decode(result, (uint256));
        return _getPastVotesRes;
    }

    function delegates(address account) external  returns (address) {
        bytes memory callHash = abi.encodeWithSignature("delegates(address)",account);
        (bool success, bytes memory result) = ve.call(callHash);
        (address _delegatesRes) = abi.decode(result, (address));
        return _delegatesRes;
    }

    function name() public  returns (string memory) {
        bytes memory callHash = abi.encodeWithSignature("name()");
        (bool success, bytes memory result) = ve.call(callHash);
        (string memory _nameRes) = abi.decode(result, (string));
        return _nameRes;
    }

    function symbol() public  returns (string memory) {
        bytes memory callHash = abi.encodeWithSignature("symbol()");
        (bool success, bytes memory result) = ve.call(callHash);
        (string memory _symbolRes) = abi.decode(result, (string));
        return _symbolRes;

    }

    function decimals() public  returns (uint8) {
        return 18;
    }

    function totalSupply() public  returns (uint256) {
        bytes memory callHash = abi.encodeWithSignature("getPastTotalSupply(uint256)", block.timestamp - 1);
        (bool success, bytes memory result) = ve.call(callHash);
        (uint256 _totalSupplyRes) = abi.decode(result, (uint256));
        return _totalSupplyRes;
    }

    function balanceOf(address _owner) public  returns (uint256 balance) {
        bytes memory callHash = abi.encodeWithSignature("getVotes(address)", _owner);
        (bool success, bytes memory result) = ve.call(callHash);
        (uint256 _balanceOfRes) = abi.decode(result, (uint256));
        return _balanceOfRes;
    }

    function transfer(address _to, uint256 _value) public returns (bool success) {
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
        return true;
    }

    function approve(address _spender, uint256 _value) public returns (bool success) {
        return true;
    }

    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
        return 0;
    }

    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}