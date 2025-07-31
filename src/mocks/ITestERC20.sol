// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ITestERC20 is IERC20 {
    function print(address _to, uint256 _amount) external;
    function mint(address _to, uint256 _amount) external;
    function burn(address _from) external;
    function decimals() external view returns (uint8);
    function admin() external view returns (address);
}