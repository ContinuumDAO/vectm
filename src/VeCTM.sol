// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.21;

import "openzeppelin/token/ERC721/ERC721.sol";
import "openzeppelin/utils/cryptography/EIP712.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin/governance/utils/Votes.sol";
import "openzeppelin/token/ERC20/IERC20.sol";


contract VeCTM is ERC721, ERC721Enumerable, Votes {
    constructor() ERC721("Vote-Escrowed Continuum", "veCTM") EIP712("CONTINUUM", "1") {}

    // STORAGE


    // PRIVATE
    function _beforeTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to , firstTokenId, batchSize);
    }

    function _afterTokenTransfer(address from, address to, uint256 firstTokenId, uint256 batchSize) internal override(ERC721) {
        _transferVotingUnits(from, to, batchSize);
        super._afterTokenTransfer(from, to, firstTokenId, batchSize);
    }

    function _getVotingUnits(address account) internal view override returns (uint256) {}


    // PUBLIC
    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function getVotingUnits(address account) external view returns (uint256) {
        return _getVotingUnits(account);
    }
}