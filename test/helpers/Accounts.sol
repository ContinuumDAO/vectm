// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import {Utils} from "./Utils.sol";

import {ITestERC20} from "./mocks/ITestERC20.sol";
import {TestERC20} from "./mocks/TestERC20.sol";

contract Accounts is Utils {
    address admin;
    address treasury;
    address committee;
    address user1;
    address user2;

    address owner;
    address proposer;
    address voter1;
    address voter2;
    address voter3;
    address voter4;
    address other;

    uint256 constant _100_000 = 100_000 ether;

    function _getAccounts() internal returns (address[] memory) {
        string memory mnemonic = "test test test test test test test test test test test junk";

        string[] memory labels = new string[](5);
        labels[0] = "Admin";
        labels[1] = "Treasury";
        labels[2] = "Committee";
        labels[3] = "User1";
        labels[4] = "User2";

        address[] memory accounts = new address[](5);

        for (uint8 i = 0; i < 5; i++) {
            uint256 pk = vm.deriveKey(mnemonic, i);
            address pub = vm.addr(pk);
            vm.label(pub, labels[i]);
            accounts[i] = pub;
        }

        return accounts;
    }

    function _getGovernanceAccounts() internal returns (address[] memory) {
        string memory mnemonic = "test test test test test test test test test test test junk";

        string[] memory labels = new string[](7);
        labels[0] = "Owner";
        labels[1] = "Proposer";
        labels[2] = "Voter1";
        labels[3] = "Voter2";
        labels[4] = "Voter3";
        labels[5] = "Voter4";
        labels[6] = "Other";

        address[] memory accounts = new address[](7);

        for (uint8 i = 0; i < 7; i++) {
            uint256 pk = vm.deriveKey(mnemonic, i + 5);
            address pub = vm.addr(pk);
            vm.label(pub, labels[i]);
            accounts[i] = pub;
        }

        return accounts;
    }

    function _dealAllERC20(address _token, uint256 _amount) internal {
        uint256 amount = _amount * 10 ** ITestERC20(_token).decimals();
        deal(_token, admin, amount, true);
        deal(_token, treasury, amount, true);
        deal(_token, committee, amount, true);
        deal(_token, user1, amount, true);
        deal(_token, user2, amount, true);

        deal(_token, owner, amount, true);
        deal(_token, proposer, amount, true);
        deal(_token, voter1, amount, true);
        deal(_token, voter2, amount, true);
        deal(_token, voter3, amount, true);
        deal(_token, voter4, amount, true);
        deal(_token, other, amount, true);
    }

    function _approveAllERC20(address _token, address[] memory _spenders) internal {
        ITestERC20 token = ITestERC20(_token);
        uint256 amount = type(uint256).max;

        _approveERC20(admin, token, amount, _spenders);
        _approveERC20(treasury, token, amount, _spenders);
        _approveERC20(committee, token, amount, _spenders);
        _approveERC20(user1, token, amount, _spenders);
        _approveERC20(user2, token, amount, _spenders);

        _approveERC20(owner, token, amount, _spenders);
        _approveERC20(proposer, token, amount, _spenders);
        _approveERC20(voter1, token, amount, _spenders);
        _approveERC20(voter2, token, amount, _spenders);
        _approveERC20(voter3, token, amount, _spenders);
        _approveERC20(voter4, token, amount, _spenders);
        _approveERC20(other, token, amount, _spenders);
    }

    function _approveERC20(address account, ITestERC20 token, uint256 amount, address[] memory _spenders) private {
        vm.startPrank(account);

        for (uint256 i = 0; i < _spenders.length; i++) {
            token.approve(_spenders[i], amount);
        }

        vm.stopPrank();
    }
}
