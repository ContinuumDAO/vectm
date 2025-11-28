// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

contract MockSwapRouter {
    bool swapCompleted;

    function swapExactTokensForTokens(uint256, uint256, address[] memory, address, uint256)
        external
        returns (uint256[] memory amounts)
    {
        swapCompleted = true;
        return new uint256[](0);
    }
}
