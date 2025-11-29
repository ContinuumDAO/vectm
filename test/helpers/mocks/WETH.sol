// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract WETH is ERC20 {
    uint8 _decimals;
    address public admin;

    constructor() ERC20("Wrapped Ether", "WETH") {
        admin = msg.sender;
        _decimals = 18;
    }

    function decimals() public view override(ERC20) returns (uint8) {
        return _decimals;
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(amount);
    }
}
