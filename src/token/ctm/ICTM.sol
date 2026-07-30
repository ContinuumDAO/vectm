// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface ICTM {
    event CTMMint(address indexed _to, uint256 _amount);
    event CTMTreasuryMint(uint256 _amount);
    event SetC3TransferFee(uint256 _amount, uint256 _minFee, uint256 _maxFee);

    event C3DepositRemote(uint256 indexed _dappID, address indexed _from, uint256 _amount, string _toChainIDStr);
    event C3DepositLocal(uint256 indexed _dappID, string indexed _fromStr, uint256 _amount, string _fromChainID);
    event DepositDAppRefund(address indexed _from, uint256 indexed _dappID, uint256 _amount, bytes _reason);

    error CTM_FeeNumeratorTooHigh();
    error CTM_ExceedsMaxSupply();
    error CTM_FeeMinGreaterThanFeeMax(uint256 _feeMin, uint256 _feeMax);
    error CTM_C3TransferAmountTooLow(uint256 _amount, uint256 _minAmount);

    function MAX_SUPPLY() external view returns (uint256);
    function FEE_DENOMINATOR() external view returns (uint256);
    function c3TransferFee() external view returns (uint256);
    function setC3TransferFee(uint256 _fee, uint256 _minFee, uint256 _maxFee) external;
    function c3transfer(string memory _toStr, uint256 _amount, string memory _toChainIDStr) external returns (bool);
    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _toChainIDStr)
        external
        returns (bool);
    function depositDAppRemote(uint256 _dappID, uint256 _amount, string memory _toChainIDStr) external;
    function depositDAppLocal(string memory _fromStr, uint256 _dappID, uint256 _amount) external;
}
