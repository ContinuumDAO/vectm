// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ITestERC20} from "./ITestERC20.sol";
import {VotingEscrowErrorParam} from "../../../src/utils/VotingEscrowUtils.sol";

contract TestERC20 is ERC20, ITestERC20 {
    uint8 _decimals;
    address public admin;

    constructor(string memory _name, string memory _symbol, uint8 decimals_) ERC20(_name, _symbol) {
        admin = msg.sender;
        _decimals = decimals_;
    }

    function decimals() public view override(ERC20, ITestERC20) returns (uint8) {
        return _decimals;
    }

    function print(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function mint(address to, uint256 amount) external override {
        require(msg.sender == admin);
        _mint(to, amount);
    }

    function burn(address from) external override {
        require(msg.sender == admin);
        if (msg.sender != admin) revert OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Admin);
        _burn(from, balanceOf(from));
    }
}
