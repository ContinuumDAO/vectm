// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { Utils } from "./Utils.sol";

import { ITestERC20 } from "../../src/mocks/ITestERC20.sol";
import { TestERC20 } from "../../src/mocks/TestERC20.sol";

contract Accounts is Utils {
    TestERC20 usdc;

    address admin;
    address gov;
    address treasury;
    address committee;
    address user1;
    address user2;

    uint256 constant _100_000 = 100_000;

    function _getAccounts() internal returns (address[] memory) {
        string memory mnemonic = "test test test test test test test test test test test junk";

        string[] memory labels = new string[](7);
        labels[0] = "Admin";
        labels[1] = "Governor";
        labels[2] = "Treasury";
        labels[3] = "Committee";
        labels[4] = "User1";
        labels[5] = "User2";

        address[] memory accounts = new address[](8);

        for (uint8 i = 0; i < 8; i++) {
            uint256 pk = vm.deriveKey(mnemonic, i);
            address pub = vm.addr(pk);
            vm.label(pub, labels[i]);
            accounts[i] = pub;
        }

        return accounts;
    }

    function _deployUSDC() internal returns (TestERC20) {
        TestERC20 _usdc = new TestERC20("Circle USD", "USDC", 6);
        return _usdc;
    }

    function _dealAllERC20(address _token, uint256 _amount) internal {
        uint256 decimals = ITestERC20(_token).decimals();
        uint256 amount = _amount * 10 ** decimals;
        deal(_token, admin, amount, true);
        deal(_token, gov, amount, true);
        deal(_token, treasury, amount, true);
        deal(_token, committee, amount, true);
        deal(_token, user1, amount, true);
        deal(_token, user2, amount, true);
    }

    function _approveAllERC20( /*address _token, uint256 _amount, FeeContracts memory feeContracts*/ ) internal {
        // ITestERC20 token = ITestERC20(_token);
        // uint256 decimals = token.decimals();
        // uint256 amount = _amount * 10 ** decimals;

        // _approveERC20(admin, token, amount, feeContracts);
        // _approveERC20(gov, token, amount, feeContracts);
        // _approveERC20(treasury, token, amount, feeContracts);
        // _approveERC20(committee, token, amount, feeContracts);
        // _approveERC20(user1, token, amount, feeContracts);
        // _approveERC20(user2, token, amount, feeContracts);
        // _approveERC20(mpc1, token, amount, feeContracts);
        // _approveERC20(mpc2, token, amount, feeContracts);
    }

    function _approveERC20( /*address account, ITestERC20 token, uint256 amount, FeeContracts memory feeContracts*/ )
        private
    {
        // vm.startPrank(account);

        // token.approve(feeContracts.rwa1X, amount);
        // token.approve(feeContracts.ctmRwaDeployInvest, amount);
        // token.approve(feeContracts.ctmRwaERC20Deployer, amount);
        // token.approve(feeContracts.identity, amount);
        // token.approve(feeContracts.sentryManager, amount);
        // token.approve(feeContracts.storageManager, amount);

        // vm.stopPrank();
    }
}