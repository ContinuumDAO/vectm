// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.27;

import {Test} from "forge-std/Test.sol";

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {C3DAppManager} from "@c3caller/dapp/C3DAppManager.sol";
import {C3UUIDKeeper} from "@c3caller/uuid/C3UUIDKeeper.sol";
import {C3Caller} from "@c3caller/C3Caller.sol";
import {IC3GovernDApp} from "@c3caller/gov/IC3GovernDApp.sol";
import {C3ErrorParam} from "@c3caller/utils/C3CallerUtils.sol";
import {ICTM} from "../../src/token/ctm/ICTM.sol";
import {CTMMintable} from "../../src/token/ctm/CTMMintable.sol";

contract FeeToken is ERC20 {
    constructor(address _supplyHolder) ERC20("Fee Token", "USDC") {
        _mint(_supplyHolder, 100_000 ether);
    }
}

contract CTMMintableTest is Test {
    C3UUIDKeeper uuidKeeper;
    C3DAppManager dappManager;
    C3Caller c3caller;

    ERC20 feeToken;
    CTMMintable ctm;

    address gov;
    address user;

    string constant CTM_DAPP_KEY = "v2.continuumdao.ctm";
    string constant CTM_METADATA =
        '{"version":2,"name":"CTM","description":"CTM V2 on Ethereum","email":"continuumdao@proton.me","url":"continuumdao.org"}';
    string constant DST_CHAIN_ID = "1";

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
        dappManager.setFeeConfig(address(feeToken), 1, 1);
        dappID = dappManager.initDAppConfig(CTM_DAPP_KEY, address(feeToken), CTM_METADATA);
        ctm = new CTMMintable(gov, address(c3caller), address(dappManager), dappID);
        dappManager.setDAppAddr(dappID, address(ctm), true);
        feeToken.approve(address(dappManager), 100 ether);
        dappManager.deposit(dappID, address(feeToken), 100 ether);
        ctm.setPeer(DST_CHAIN_ID, vm.toString(address(ctm)));

        vm.stopPrank();
    }

    // ============================
    // ======== DEPLOYMENT ========
    // ============================

    function test_Deployment() public view {
        assertEq(ctm.globalSupply(), 0);
        assertEq(ctm.MAX_SUPPLY(), 100_000_000 ether);
    }

    // ============================
    // ======== MINT ================
    // ============================

    function test_Mint_Success() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit ICTM.CTMMint(user, 100 ether);
        ctm.mint(user, 100 ether);
        assertEq(ctm.balanceOf(user), 100 ether);
        assertEq(ctm.globalSupply(), 100 ether);
    }

    function test_Mint_TreasuryMint() public {
        vm.prank(gov);
        vm.expectEmit(true, true, true, true);
        emit ICTM.CTMTreasuryMint(100 ether);
        ctm.mint(gov, 100 ether);
        assertEq(ctm.balanceOf(gov), 100 ether);
        assertEq(ctm.globalSupply(), 100 ether);
    }

    function test_Mint_RevertWhen_ExceedsMaxSupply() public {
        uint256 maxSupply = ctm.MAX_SUPPLY();
        vm.startPrank(gov);
        ctm.mint(user, maxSupply);
        vm.expectRevert(abi.encodeWithSelector(ICTM.CTM_ExceedsMaxSupply.selector));
        ctm.mint(user, 1);
        vm.stopPrank();
    }

    function test_Mint_RevertWhen_NotGov() public {
        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                IC3GovernDApp.C3GovernDApp_OnlyAuthorized.selector, C3ErrorParam.Sender, C3ErrorParam.Gov
            )
        );
        ctm.mint(user, 100 ether);
    }

    function testFuzz_Mint_UpdatesGlobalSupply(uint256 amount) public {
        amount = bound(amount, 1, ctm.MAX_SUPPLY());
        vm.prank(gov);
        ctm.mint(user, amount);
        assertEq(ctm.balanceOf(user), amount);
        assertEq(ctm.globalSupply(), amount);
    }

    // ============================
    // ======== BURN ================
    // ============================

    function test_Burn_Success() public {
        vm.prank(gov);
        ctm.mint(user, 100 ether);
        vm.prank(user);
        ctm.burn(40 ether);
        assertEq(ctm.balanceOf(user), 60 ether);
        assertEq(ctm.globalSupply(), 60 ether);
    }

    function test_Burn_RevertWhen_InsufficientBalance() public {
        vm.prank(user);
        vm.expectRevert();
        ctm.burn(1 ether);
    }
}
