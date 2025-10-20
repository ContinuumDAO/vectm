// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract CTM is ERC20 {
    constructor(address _admin) ERC20("Continuum", "CTM") {
        _mint(_admin, 100_000_000 ether);
    }

    function burn(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
