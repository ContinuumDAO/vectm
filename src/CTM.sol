// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {TheiaERC20} from "./theia/TheiaERC20.sol";

contract CTM is TheiaERC20 {
    constructor(address _governor) TheiaERC20("Continuum", "CTM", 18, address(this), _governor) {
        _mint(msg.sender, 100000000 ether);
    }

    // TEST ONLY
    function print(address to, uint256 amount) external {
        _mint(to, amount);
    }
}