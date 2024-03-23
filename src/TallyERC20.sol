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
    IVotingEscrow ve = IVotingEscrow(0xAF0D3b20ac92e6825014549bB3FA937b3BF5731A);

    function getVotes(address account) external view returns (uint256) {
        return ve.getVotes(account);
    }

    function getPastVotes(address account, uint256 timepoint) external view returns (uint256) {
        return ve.getPastVotes(account, timepoint - 1);
    }

    function delegates(address account) external view returns (address) {
        return ve.delegates(account);
    }

    function name() public view returns (string memory) {
        return ve.name();
    }

    function symbol() public view returns (string memory) {
        return ve.symbol();
    }

    function decimals() public view returns (uint8) {
        return 18;
    }

    function totalSupply() public view returns (uint256) {
        return ve.getPastTotalSupply(block.timestamp - 1);
    }

    function balanceOf(address _owner) public view returns (uint256 balance) {
        return ve.getVotes(_owner);
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