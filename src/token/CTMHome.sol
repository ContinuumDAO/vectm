// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {CTM} from "./CTM.sol";

interface ICTMHome {
    function mint(address _to, uint256 _amount) external;
}

contract CTMHome is ICTMHome, CTM {
    constructor (address _c3caller, uint256 _dappID) CTM( _c3caller, _dappID) {}

    function mint(address _to, uint256 _amount) external onlyGov {
        if (totalSupply() + _amount > MAX_SUPPLY) revert CTM_ExceedsMaxSupply();
        _mint(_to, _amount);

        if (_to == gov()) {
            emit CTMTreasuryMint(_amount);
        } else {
            emit CTMMint(_to, _amount);
        }
    }
}
