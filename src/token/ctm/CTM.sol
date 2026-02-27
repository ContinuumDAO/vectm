// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

import {CTMERC20} from "@c3caller/token/CTMERC20.sol";
import {IC3DAppManager} from "@c3caller/dapp/IC3DAppManager.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {C3CallerUtils} from "@c3caller/utils/C3CallerUtils.sol";

import {ICTM} from "./ICTM.sol";

contract CTM is ICTM, CTMERC20 {
    using Strings for address;
    using C3CallerUtils for *;

    uint256 public constant MAX_SUPPLY = 100_000_000 ether;
    uint256 public constant FEE_DENOMINATOR = 10_000;

    address public dappManager;

    uint256 public c3TransferFee;
    uint256 public c3TransferMinFee;
    uint256 public c3TransferMaxFee;

    constructor(address _gov, address _c3caller, address _dappManager, uint256 _dappID)
        CTMERC20("Continuum", "CTM", _gov, _c3caller, _dappID)
    {
        // initial fee = 1%
        c3TransferFee = 100;
        // initial minimum fee = 1 CTM
        c3TransferMinFee = 5 ether;
        // initial maximum fee = 100 CTM
        c3TransferMaxFee = 20 ether;
        dappManager = _dappManager;
    }

    function setC3TransferFee(uint256 _fee, uint256 _minFee, uint256 _maxFee) external onlyGov {
        // max fee is 10%
        if (_fee > 1_000) revert CTM_FeeNumeratorTooHigh();
        if (_minFee >= _maxFee) revert CTM_FeeMinGreaterThanFeeMax(_minFee, _maxFee);
        c3TransferFee = _fee;
        c3TransferMinFee = _minFee;
        c3TransferMaxFee = _maxFee;
        emit SetC3TransferFee(_fee, _minFee, _maxFee);
    }

    function depositDAppRemote(uint256 _dappID, uint256 _amount, string memory _toChainIDStr) external {
        if (bytes(peers[_toChainIDStr]).length == 0) revert CTMERC20_InvalidChainID(_toChainIDStr);
        address _from = _msgSender();
        _burn(_from, _amount);
        uint256 netAmount = _deductFee(_amount);
        string memory _fromStr = _from.toHexString();
        bytes memory depositDAppCall =
            abi.encodeWithSelector(this.depositDAppLocal.selector, _fromStr, _dappID, netAmount);
        _c3call(peers[_toChainIDStr], _toChainIDStr, depositDAppCall);
        emit C3DepositRemote(_dappID, _from, netAmount, _toChainIDStr);
    }

    function depositDAppLocal(string memory _fromStr, uint256 _dappID, uint256 _amount) external onlyC3Caller {
        (, string memory _fromChainID,) = _context();
        _mint(address(this), _amount);
        _approve(address(this), dappManager, _amount);
        IC3DAppManager(dappManager).deposit(_dappID, address(this), _amount);
        emit C3DepositLocal(_dappID, _fromStr, _amount, _fromChainID);
    }

    function c3transfer(string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        public
        override(ICTM, CTMERC20)
        returns (bool)
    {
        uint256 netAmount = _deductFee(_amount);
        return super.c3transfer(_toStr, netAmount, _toChainIDStr);
    }

    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        public
        override(ICTM, CTMERC20)
        returns (bool)
    {
        uint256 netAmount = _deductFee(_amount);
        return super.c3transferFrom(_from, _toStr, netAmount, _toChainIDStr);
    }

    function _deductFee(uint256 _amount) internal returns (uint256) {
        uint256 netAmount = _amount;
        if (msg.sender != gov()) {
            uint256 fee = c3TransferFee * _amount / FEE_DENOMINATOR;
            if (fee < c3TransferMinFee) fee = c3TransferMinFee;
            else if (fee > c3TransferMaxFee) fee = c3TransferMaxFee;
            _transfer(msg.sender, gov(), fee);
            netAmount = _amount - fee;
        }
        return netAmount;
    }

    function _c3Fallback(bytes4 _selector, bytes calldata _data, bytes calldata _reason)
        internal
        virtual
        override
        returns (bool)
    {
        bool complete = super._c3Fallback(_selector, _data, _reason);
        if (!complete) {
            if (_selector == this.depositDAppLocal.selector) {
                (string memory _fromStr, uint256 _dappID, uint256 _amount) =
                    abi.decode(_data, (string, uint256, uint256));
                address _from = _fromStr.toAddress();
                _mint(_from, _amount);
                emit DepositDAppRefund(_from, _dappID, _amount, _reason);
                complete = true;
            }
        }
        return complete;
    }

    // NOTE: `globalSupply` is only minted on home instance
    function _incrementGlobalSupply(uint256 _amount) internal virtual override {}

    // NOTE: `globalSupply` is only burned on home instance
    function _decrementGlobalSupply(uint256 _amount) internal virtual override {}
}
