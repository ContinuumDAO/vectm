// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface ICTM {
    event CTMMint(address indexed _to, uint256 _amount);
    event CTMTreasuryMint(uint256 _amount);
    event SetC3TransferFee(uint256 _amount);

    error CTM_FeeNumeratorTooHigh();
    error CTM_ExceedsMaxSupply();

    function MAX_SUPPLY() external view returns (uint256);
    function FEE_DENOMINATOR() external view returns (uint256);
    function c3TransferFee() external view returns (uint256);
    function setC3TransferFee(uint256 _fee) external;
    function c3transfer(string memory _toStr, uint256 _amount, string memory _toChainIDStr) external returns (bool);
    function c3transferFrom(address _from, string memory _toStr, uint256 _amount, string memory _toChainIDStr) external returns (bool);
}
