// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {CTMERC20} from "@c3caller/token/CTMERC20.sol";
import {ICTM} from "./ICTM.sol";

contract CTM is ICTM, CTMERC20 {
    uint256 public constant MAX_SUPPLY = 100_000_000 ether;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    uint256 public c3TransferFee;

    constructor (address _c3caller, uint256 _dappID) CTMERC20("Continuum", "CTM", _c3caller, _dappID) {
        // initial fee = 1%
        c3TransferFee = 100;
    }

    function setC3TransferFee(uint256 _fee) external onlyGov {
        // max fee is 10%
        if (_fee > 1_000) revert CTM_FeeNumeratorTooHigh();
        c3TransferFee = _fee;
        emit SetC3TransferFee(_fee);
    }

    function c3transfer(string memory _toStr, uint256 _amount, string memory _toChainIDStr) public override(ICTM, CTMERC20) returns (bool) {
        uint256 netAmount = _amount;
        if (msg.sender != gov()) {
            uint256 fee = c3TransferFee * _amount / FEE_DENOMINATOR;
            transferFrom(msg.sender, gov(), fee);
            netAmount = _amount - fee;
        }
        return super.c3transfer(_toStr, netAmount, _toChainIDStr);
    }

    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _toChainIDStr) public override(ICTM, CTMERC20) returns (bool) {
        uint256 fee = c3TransferFee * _amount / FEE_DENOMINATOR;
        transferFrom(msg.sender, gov(), fee);
        return super.c3transferFrom(_from, _toStr, _amount - fee, _toChainIDStr);
    }
}
