// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

import {TheiaERC20} from "./theia/TheiaERC20.sol";

interface IERC20Received {
    function onERC20Received(address token, bytes memory data) external;
}

contract CTM is TheiaERC20 {
    constructor(address _admin) TheiaERC20("Continuum", "CTM", 18, address(0), _admin) {
        _mint(_admin, 100_000_000 ether);
    }
}