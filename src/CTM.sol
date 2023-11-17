// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "@openzeppelin/token/ERC20/ERC20.sol";

contract CTM is ERC20 {
    constructor() ERC20("Continuum", "CTM") {
        _mint(msg.sender, 100000000 ether);
    }
}
