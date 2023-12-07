// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract CTM is ERC20 {
    constructor() ERC20("Continuum", "CTM") {
        _mint(msg.sender, 100000000 ether);
    }

    // TEST ONLY
    function print(address to, uint256 amount) external {
        _mint(to, amount);
    }
}
