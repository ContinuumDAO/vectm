// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

interface ITheiaERC20 {
    function decimals() external returns (uint8);

    function mint(address to, uint256 amount) external returns (bool);

    function burn(address from, uint256 amount) external returns (bool);

    function setMinter(address _auth) external;

    function applyMinter() external;

    function revokeMinter(address _auth) external;

    function changeVault(address newVault) external returns (bool);

    function depositVault(
        uint256 amount,
        address to
    ) external returns (uint256);

    function withdrawVault(
        address from,
        uint256 amount,
        address to
    ) external returns (uint256);

    function underlying() external view returns (address);

    function deposit(uint256 amount, address to) external returns (uint256);

    function withdraw(uint256 amount, address to) external returns (uint256);

    function setFeeConfig(
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom
    ) external returns (bool);

    function getFeeConfig(
        uint256 fromChainID,
        uint256 toChainID
    ) external view returns (uint256, uint256, uint256);
}