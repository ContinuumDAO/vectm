// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {CTM} from "./CTM.sol";
import {ICTMMintable} from "./ICTMMintable.sol";

contract CTMMintable is ICTMMintable, CTM {
    constructor(address _gov, address _c3caller, address _dappManager, uint256 _dappID)
        CTM(_gov, _c3caller, _dappManager, _dappID)
    {}

    function _incrementGlobalSupply(uint256 _amount) internal override {
        globalSupply += _amount;
    }

    function _decrementGlobalSupply(uint256 _amount) internal override {
        globalSupply -= _amount;
    }

    function burn(uint256 _amount) external {
        _decrementGlobalSupply(_amount);
        _burn(msg.sender, _amount);
    }

    function mint(address _to, uint256 _amount) external onlyGov {
        if (totalSupply() + _amount > MAX_SUPPLY) revert CTM_ExceedsMaxSupply();
        _incrementGlobalSupply(_amount);
        _mint(_to, _amount);

        if (_to == gov()) {
            emit CTMTreasuryMint(_amount);
        } else {
            emit CTMMint(_to, _amount);
        }
    }
}
