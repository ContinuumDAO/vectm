// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "openzeppelin/token/ERC20/ERC20.sol";


contract CTM is ERC20 {
    constructor() ERC20("Continuum", "CTM") {}

    // TEST ONLY
    function print(address recipient, uint256 amount) public {
        _mint(recipient, amount);
    }
}