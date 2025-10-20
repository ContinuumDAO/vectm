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

    function _dealAllERC20(address _token, uint256 _amount) internal {
        uint256 amount = _amount * 10 ** ITestERC20(_token).decimals();
        deal(_token, admin, amount, true);
        deal(_token, treasury, amount, true);
        deal(_token, committee, amount, true);
        deal(_token, user1, amount, true);
        deal(_token, user2, amount, true);
    }

    function _approveAllERC20(address _token, address[] memory _spenders) internal {
        ITestERC20 token = ITestERC20(_token);
        uint256 amount = type(uint256).max;

        _approveERC20(admin, token, amount, _spenders);
        _approveERC20(treasury, token, amount, _spenders);
        _approveERC20(committee, token, amount, _spenders);
        _approveERC20(user1, token, amount, _spenders);
        _approveERC20(user2, token, amount, _spenders);
    }

    function _approveERC20(address account, ITestERC20 token, uint256 amount, address[] memory _spenders) private {
        vm.startPrank(account);

        for (uint256 i = 0; i < _spenders.length; i++) {
            token.approve(_spenders[i], amount);
        }

        vm.stopPrank();
    }
}
