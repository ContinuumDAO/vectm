// SPDX-License-Identifier: BSL-1.1

pragma solidity 0.8.27;

interface ICTMMintable {
    event CTMTrueBurn(address indexed _from, uint256 _amount);

    error CTM_ExceedsMaxSupply();

    function maxSupply() external view returns (uint256);
    function mint(address _to, uint256 _amount) external;
    function burn(uint256 _amount) external;
    function trueBurn(uint256 _amount) external;
}
