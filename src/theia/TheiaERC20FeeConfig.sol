// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.23;

contract TheiaERC20FeeConfig {
    struct FeeConfig {
        uint256 MaximumSwapFee; // FixFee if MaximumSwapFee == MinimumSwapFee
        uint256 MinimumSwapFee;
        uint256 SwapFeeRatePerMillion;
    }
    uint256 public constant FROM_CHAIN_PAY = 1;
    uint256 public constant TO_CHAIN_PAY = 2;

    mapping(uint256 => FeeConfig) public _fromFeeConfigs; // key is fromChainID
    mapping(uint256 => FeeConfig) public _toFeeConfigs; // key is toChainID

    function _setFeeConfig(
        uint256 srcChainID,
        uint256 dstChainID,
        uint256 maxFee,
        uint256 minFee,
        uint256 feeRate,
        uint256 payFrom // 1:from 2:to 0:free
    ) internal returns (bool) {
        require(
            payFrom == FROM_CHAIN_PAY || payFrom == TO_CHAIN_PAY,
            "FeeConfig: Invalid payFrom"
        );
        FeeConfig memory fee = FeeConfig(maxFee, minFee, feeRate);
        if (payFrom == FROM_CHAIN_PAY) {
            _toFeeConfigs[dstChainID] = fee;
        } else {
            _fromFeeConfigs[srcChainID] = fee;
        }
        return true;
    }

    function getSwapInFeeConfig(
        uint256 fromChainID
    ) public view returns (uint256, uint256, uint256) {
        FeeConfig memory fee = _fromFeeConfigs[fromChainID];
        return (
            fee.MaximumSwapFee,
            fee.MinimumSwapFee,
            fee.SwapFeeRatePerMillion
        );
    }

    function getSwapOutFeeConfig(
        uint256 toChainID
    ) public view returns (uint256, uint256, uint256) {
        FeeConfig memory fee = _toFeeConfigs[toChainID];
        return (
            fee.MaximumSwapFee,
            fee.MinimumSwapFee,
            fee.SwapFeeRatePerMillion
        );
    }
}