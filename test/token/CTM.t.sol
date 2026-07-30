// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {console} from "forge-std/console.sol";
import {Test} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {ICTMERC20} from "@c3caller/token/ICTMERC20.sol";
import {C3DAppManager} from "@c3caller/dapp/C3DAppManager.sol";
import {IC3UUIDKeeper, C3UUIDKeeper} from "@c3caller/uuid/C3UUIDKeeper.sol";
import {IC3Caller, C3Caller} from "@c3caller/C3Caller.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IC3CallerDApp} from "@c3caller/dapp/IC3CallerDApp.sol";
import {C3ErrorParam} from "@c3caller/utils/C3CallerUtils.sol";
import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";
import {ICTM, CTM} from "../../src/token/ctm/CTM.sol";

contract CTMHarness is CTM {
    constructor(address _gov, address _c3caller, address _dappManager, uint256 _dappID)
        CTM(_gov, _c3caller, _dappManager, _dappID)
    {}

    function harnessIncrementGlobalSupply(uint256 _amount) external {
        _incrementGlobalSupply(_amount);
    }

    function harnessDecrementGlobalSupply(uint256 _amount) external {
        _decrementGlobalSupply(_amount);
    }
}

contract FeeToken is ERC20 {
    constructor(address _supplyHolder) ERC20("Fee Token", "USDC") {
        _mint(_supplyHolder, 100_000 ether);
    }
}

contract CTMTest is Test {
    using Strings for address;

    C3UUIDKeeper uuidKeeper;
    C3DAppManager dappManager;
    C3Caller c3caller;

    ERC20 feeToken;
    CTM ctm;

    address gov;
    address user;

    string constant CTM_DAPP_KEY = "v2.continuumdao.ctm";
    string constant CTM_METADATA =
        '{"version":2,"name":"CTM","description":"CTM V2 on Ethereum","email":"continuumdao@proton.me","url":"continuumdao.org"}';
    string constant DST_CHAIN_ID = "1";
    string constant SRC_CHAIN_ID = "59144";

    string peerCTMStr;

    uint256 constant PAYLOAD_PER_BYTE_FEE = 1;
    uint256 constant GAS_PER_ETHER_FEE = 1;

    uint256 dappID;

    function setUp() public {
        gov = makeAddr("gov");
        user = makeAddr("user");

        vm.startPrank(gov);

        feeToken = new FeeToken(gov);
        uuidKeeper = new C3UUIDKeeper();
        dappManager = new C3DAppManager();
        c3caller = new C3Caller(address(uuidKeeper), address(dappManager));
        c3caller.addMPC(address(this));
        c3caller.activateChainID(DST_CHAIN_ID);
        uuidKeeper.setC3Caller(address(c3caller));
        dappManager.setC3Caller(address(c3caller));
        dappManager.setFeeConfig(address(feeToken), PAYLOAD_PER_BYTE_FEE, GAS_PER_ETHER_FEE);
        dappID = dappManager.initDAppConfig(CTM_DAPP_KEY, address(feeToken), CTM_METADATA);
        ctm = new CTM(gov, address(c3caller), address(dappManager), dappID);
        peerCTMStr = vm.toString(address(ctm));
        dappManager.setDAppAddr(dappID, address(ctm), true);
        feeToken.approve(address(dappManager), 100 ether);
        dappManager.deposit(dappID, address(feeToken), 100 ether);
        ctm.setPeer(DST_CHAIN_ID, peerCTMStr);

        vm.stopPrank();
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public view {
        assertEq(ctm.c3TransferFee(), 100);
        assertEq(ctm.c3TransferMinFee(), 5 ether);
        assertEq(ctm.c3TransferMaxFee(), 20 ether);
        assertEq(ctm.dappManager(), address(dappManager));
    }

    // =====================================
    // ======== SET C3 TRANSFER FEE ========
    // =====================================

    function test_SetC3TransferFee_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit ICTM.SetC3TransferFee(50, 10 ether, 20 ether);
        ctm.setC3TransferFee(50, 10 ether, 20 ether); // INFO: 50 -> 0.5%
        assertEq(ctm.c3TransferFee(), 50);
        assertEq(ctm.c3TransferMinFee(), 10 ether);
        assertEq(ctm.c3TransferMaxFee(), 20 ether);
    }

    function test_SetC3TransferFee_RevertWhen_FeeNumeratorTooHigh() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(ICTM.CTM_FeeNumeratorTooHigh.selector));
        ctm.setC3TransferFee(1001, 10 ether, 20 ether);
    }

    function test_SetC3TransferFee_RevertWhen_FeeMinGreaterThanFeeMax() public {
        vm.prank(gov);
        vm.expectRevert(abi.encodeWithSelector(ICTM.CTM_FeeMinGreaterThanFeeMax.selector, 20 ether, 10 ether));
        ctm.setC3TransferFee(50, 20 ether, 10 ether);
    }

    function test_SetC3TransferFee_RevertWhen_NotGov() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        ctm.setC3TransferFee(50, 10 ether, 20 ether);
    }

    // =============================
    // ======== C3 TRANSFER ========
    // =============================

    function test_C3Transfer_Success() public {
        deal(address(ctm), address(this), 501 ether, true); // INFO: 1% fee is applied > 500 CTM and < 2000 CTM
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(address(this), "to_address", 495.99 ether, DST_CHAIN_ID); // INFO: 501 - (0.01)(501) = 501 - 5.01 = 495.99
        ctm.c3transfer("to_address", 501 ether, DST_CHAIN_ID);
    }

    function test_C3Transfer_ZeroGovFee() public {
        deal(address(ctm), address(gov), 100 ether, true);
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(gov, "to_address", 100 ether, DST_CHAIN_ID);
        ctm.c3transfer("to_address", 100 ether, DST_CHAIN_ID);
    }

    function test_C3Transfer_RevertWhen_AmountBelowMinimum() public {
        deal(address(ctm), address(this), 5 ether, true);
        vm.expectRevert(abi.encodeWithSelector(ICTM.CTM_C3TransferAmountTooLow.selector, 5 ether, 5 ether + 1));
        ctm.c3transfer("to_address", 5 ether, DST_CHAIN_ID);
    }

    function testFuzz_C3Transfer_Fee(uint256 amount) public {
        uint256 feeDenominator = ctm.FEE_DENOMINATOR();
        uint256 feeShare = ctm.c3TransferFee();
        uint256 minFee = ctm.c3TransferMinFee();
        uint256 maxFee = ctm.c3TransferMaxFee();
        amount = bound(amount, minFee + 1, 100_000_000 ether);
        uint256 fee = feeShare * amount / feeDenominator;
        uint256 expectedFee;
        if (fee < minFee) {
            expectedFee = minFee;
        } else if (fee > maxFee) {
            expectedFee = maxFee;
        } else {
            expectedFee = fee;
        }
        deal(address(ctm), address(this), amount);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(address(this), "to_address", amount - expectedFee, DST_CHAIN_ID);
        ctm.c3transfer("to_address", amount, DST_CHAIN_ID);
    }

    function test_C3TransferFrom_Success() public {
        deal(address(ctm), user, 501 ether, true); // INFO: 1% fee is applied > 500 CTM and < 2000 CTM
        vm.prank(user);
        ctm.approve(address(this), 501 ether);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(user, "to_address", 495.99 ether, DST_CHAIN_ID); // INFO: 501 - (0.01)(501) = 501 - 5.01 = 495.99
        ctm.c3transferFrom(user, "to_address", 501 ether, DST_CHAIN_ID);
    }

    function test_C3TransferFrom_InsufficientAllowanceForFee() public {
        deal(address(ctm), user, 500 ether, true);
        vm.prank(user);
        ctm.approve(address(this), 4.9 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 4.9 ether, 5 ether)
        );
        ctm.c3transferFrom(user, "to_address", 500 ether, DST_CHAIN_ID);
    }

    function test_C3TransferFrom_InsufficientAllowanceForAmount() public {
        deal(address(ctm), user, 500 ether, true);
        vm.prank(user);
        ctm.approve(address(this), 5 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(this), 0, 495 ether)
        );
        ctm.c3transferFrom(user, "to_address", 500 ether, DST_CHAIN_ID);
    }

    function test_C3TransferFrom_ZeroGovFee() public {
        deal(address(ctm), address(gov), 100 ether, true);
        vm.prank(gov);
        ctm.approve(address(this), 100 ether);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(gov, "to_address", 100 ether, DST_CHAIN_ID);
        ctm.c3transferFrom(gov, "to_address", 100 ether, DST_CHAIN_ID);
    }

    function test_C3TransferFrom_RevertWhen_AmountBelowMinimum() public {
        deal(address(ctm), user, 5 ether, true);
        vm.expectRevert(abi.encodeWithSelector(ICTM.CTM_C3TransferAmountTooLow.selector, 5 ether, 5 ether + 1));
        ctm.c3transferFrom(user, "to_address", 5 ether, DST_CHAIN_ID);
    }

    function testFuzz_C3TransferFrom_Fee(uint256 amount) public {
        uint256 feeDenominator = ctm.FEE_DENOMINATOR();
        uint256 feeShare = ctm.c3TransferFee();
        uint256 minFee = ctm.c3TransferMinFee();
        uint256 maxFee = ctm.c3TransferMaxFee();
        amount = bound(amount, minFee + 1, 100_000_000 ether);
        uint256 fee = feeShare * amount / feeDenominator;
        uint256 expectedFee;
        if (fee < minFee) {
            expectedFee = minFee;
        } else if (fee > maxFee) {
            expectedFee = maxFee;
        } else {
            expectedFee = fee;
        }
        deal(address(ctm), user, amount);
        vm.prank(user);
        ctm.approve(address(this), amount);
        vm.expectEmit(true, true, true, true);
        emit ICTMERC20.C3Transfer(user, "to_address", amount - expectedFee, DST_CHAIN_ID);
        ctm.c3transferFrom(user, "to_address", amount, DST_CHAIN_ID);
    }

    // =====================================
    // ======== DEPOSIT DAPP REMOTE ========
    // =====================================

    function test_DepositDAppRemote_Success() public {
        deal(address(ctm), address(this), 100 ether, true);
        vm.expectEmit(true, true, true, true);
        emit ICTM.C3DepositRemote(dappID, address(this), 95 ether, DST_CHAIN_ID);
        ctm.depositDAppRemote(dappID, 100 ether, DST_CHAIN_ID);
        assertEq(ctm.balanceOf(gov), 5 ether);
    }

    function test_DepositDAppRemote_RevertWhen_InvalidChainID() public {
        vm.expectRevert(abi.encodeWithSelector(ICTMERC20.CTMERC20_InvalidChainID.selector, "invalid_chain"));
        ctm.depositDAppRemote(dappID, 100 ether, "invalid_chain");
    }

    // ====================================
    // ======== DEPOSIT DAPP LOCAL ========
    // ====================================

    function test_DepositDAppLocal_Success() public {
        vm.prank(gov);
        dappManager.setFeeConfig(address(ctm), 1, 1);
        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit ICTM.C3DepositLocal(dappID, "from_address", 100 ether, "");
        ctm.depositDAppLocal("from_address", dappID, 100 ether);
    }

    function test_DepositDAppLocal_RevertWhen_NotC3Caller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3CallerDApp.C3CallerDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.C3Caller
            )
        );
        ctm.depositDAppLocal("from_address", dappID, 100 ether);
    }

    // ==================================
    // ======== C3 FALLBACK =============
    // ==================================

    function test_C3Fallback_DepositDAppLocal_Refund() public {
        string memory fromStr = vm.toString(user);
        uint256 amount = 95 ether;
        bytes memory data = abi.encodeWithSelector(ctm.depositDAppLocal.selector, fromStr, dappID, amount);
        bytes memory reason = abi.encodeWithSignature("Error(string)", "deposit failed");

        vm.prank(address(c3caller));
        vm.expectEmit(true, true, true, true);
        emit ICTM.DepositDAppRefund(user, dappID, amount, reason);
        bool success = ctm.c3Fallback(dappID, data, reason);
        assertTrue(success);
        assertEq(ctm.balanceOf(user), amount);
    }

    function test_C3Fallback_C3Receive_DelegatesToSuper() public {
        string memory fromStr = vm.toString(user);
        string memory toStr = vm.toString(address(this));
        uint256 amount = 100 ether;
        bytes memory data = abi.encodeWithSelector(ctm.c3receive.selector, fromStr, toStr, amount);
        bytes memory reason = abi.encodeWithSignature("Error(string)", "receive failed");

        vm.prank(address(c3caller));
        bool success = ctm.c3Fallback(dappID, data, reason);
        assertTrue(success);
        assertEq(ctm.balanceOf(user), amount);
    }

    function test_C3Fallback_ReturnsFalseForUnknownSelector() public {
        bytes memory data = abi.encodeWithSelector(bytes4(0xdeadbeef), uint256(1));
        bytes memory reason = abi.encodeWithSignature("Error(string)", "unknown failure");

        vm.prank(address(c3caller));
        bool success = ctm.c3Fallback(dappID, data, reason);
        assertFalse(success);
    }

    // =========================================
    // ======== GLOBAL SUPPLY NO-OPS ===========
    // =========================================

    function test_GlobalSupplyHooks_NoOp() public {
        CTMHarness harness = new CTMHarness(gov, address(c3caller), address(dappManager), dappID);
        harness.harnessIncrementGlobalSupply(100 ether);
        harness.harnessDecrementGlobalSupply(100 ether);
        assertEq(harness.globalSupply(), 0);
    }
}
