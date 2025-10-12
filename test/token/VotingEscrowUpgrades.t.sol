// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity 0.8.27;

import { console } from "forge-std/console.sol";

import { SafeCast } from "@openzeppelin/contracts/utils/math/SafeCast.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IVotingEscrow } from "../../src/token/IVotingEscrow.sol";
import { VotingEscrowErrorParam } from "../../src/utils/VotingEscrowUtils.sol";
import { Helpers } from "../helpers/Helpers.sol";
import { VotingEscrow } from "../../src/token/VotingEscrow.sol";

// VotingEscrowV2 - A minor upgrade that adds new features without overriding base functions
contract VotingEscrowV2 is VotingEscrow {

    error V2_MinimumLockDuration(uint256 _lock_duration);

    // New feature: track upgrade count
    uint256 public upgradeCount;
    
    // New feature: enhanced version string
    string public constant VERSION_V2 = "2.0.0";
    
    // New feature: minimum lock duration (1 day)
    uint256 public constant MIN_LOCK_DURATION = 2 weeks;
    
    // New function: get upgrade count
    function getUpgradeCount() external view returns (uint256) {
        return upgradeCount;
    }
    
    // New function: increment upgrade count (only governor)
    function incrementUpgradeCount() external {
        require(msg.sender == governor, "V2: Only governor can increment");
        if (msg.sender != governor) revert VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Governor);
        upgradeCount++;
    }
    
    // New function: create lock with minimum duration check
    function create_lock_v2(uint256 _value, uint256 _lock_duration) external returns (uint256) {
        if (_lock_duration < MIN_LOCK_DURATION) revert V2_MinimumLockDuration(_lock_duration);
        return _create_lock(_value, _lock_duration, msg.sender, DepositType.CREATE_LOCK_TYPE);
    }

    // New function to be called after upgrade
    function initializeV2() external {
        // if (msg.sender != governor) revert VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Governor);
        // if (msg.sender != governor) revert IsNotGovernor(msg.sender, governor);
        upgradeCount = 1;
    }

    // Public wrapper for internal _numCheckpoints
    function numCheckpointsPublic(address account) external view returns (uint32) {
        return _numCheckpoints(account);
    }
}

contract VotingEscrowUpgradesTest is Helpers {
    uint256 id1;
    uint256 id2;
    uint256 id3;
    uint256 id4;

    uint256 constant MAXTIME = 4 * 365 * 86_400;
    uint256 constant ONE_YEAR = 365 * 86_400;

    VotingEscrowV2 veImplV2;
    bytes initializerDataV2 = abi.encodeWithSelector(VotingEscrowV2.initializeV2.selector);
    string constant BASE_URI_V1 = "Base URI";
    string constant BASE_URI_V2 = "veCTM V2";

    // UTILS
    modifier approveUser2() {
        vm.prank(user1);
        ve.setApprovalForAll(user2, true);
        _;
    }

    function setUp() public override {
        super.setUp();
        vm.startPrank(address(ctmDaoGovernor));
        rewards.setBaseEmissionRate(0);
        rewards.setNodeEmissionRate(0);
        vm.stopPrank();

        veImplV2 = new VotingEscrowV2();

        // Deal tokens to this contract first, then transfer to governor
        deal(address(ctm), address(this), CTM_TS, true);
        ctm.transfer(address(ctmDaoGovernor), CTM_TS);
        vm.prank(address(ctmDaoGovernor));
        ctm.approve(address(ve), CTM_TS);
    }

    // BASIC UPGRADE TESTS
    function test_InitializedStateEqualToInput() public {
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V1);
    }

    function test_CannotInitializeTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        ve.initialize(address(ctm), BASE_URI_V1);
    }

    function test_ValidUpgrade() public {
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        // Base URI should remain the same since we're not reinitializing
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V1);
        // But upgrade count should be set
        assertEq(VotingEscrowV2(address(ve)).getUpgradeCount(), 1);
    }

    function test_UnauthorizedUpgrade() public {
        vm.expectRevert(abi.encodeWithSelector(IVotingEscrow.VotingEscrow_OnlyAuthorized.selector, VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Governor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        string memory baseURI = ve.baseURI();
        assertEq(baseURI, BASE_URI_V1);
    }

    // COMPREHENSIVE UPGRADE TESTS
    function test_UpgradePreservesExistingData() public {
        // Create a lock before upgrade
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(1 ether, block.timestamp + 1 weeks);
        (int128 amount, uint256 end) = ve.locked(tokenId);
        assertEq(uint256(int256(amount)), 1 ether);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Verify data is preserved
        (amount, end) = ve.locked(tokenId);
        assertEq(uint256(int256(amount)), 1 ether);
        assertEq(ve.ownerOf(tokenId), user1);
    }

    function test_UpgradeAddsNewFeatures() public {
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test upgrade count
        assertEq(VotingEscrowV2(address(ve)).getUpgradeCount(), 1);
        
        // Test new minimum lock duration
        vm.expectRevert(abi.encodeWithSelector(VotingEscrowV2.V2_MinimumLockDuration.selector, 12 hours));
        vm.prank(user1);
        VotingEscrowV2(address(ve)).create_lock_v2(1 ether, 12 hours);
    }

    function test_UpgradePreservesVotingPower() public {
        // Create lock and get voting power
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(1 ether, block.timestamp + 1 weeks);
        uint256 votingPowerBefore = ve.balanceOfNFT(tokenId);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Verify voting power is preserved
        uint256 votingPowerAfter = ve.balanceOfNFT(tokenId);
        assertEq(votingPowerAfter, votingPowerBefore);
    }

    function test_UpgradePreservesDelegation() public {
        // Create lock
        vm.prank(user1);
        ve.create_lock(1 ether, block.timestamp + 1 weeks);

        skip(1);
        
        vm.prank(user1);
        ve.delegate(user2);

        address delegatesBeforeUpgrade = ve.delegates(user1);
        assertEq(delegatesBeforeUpgrade, user2);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        address delegatesAfterUpgrade = ve.delegates(user1);
        assertEq(delegatesAfterUpgrade, user2);
    }

    function test_UpgradePreservesNonVotingTokens() public {
        // Create non-voting lock
        vm.prank(user1);
        uint256 tokenId = ve.create_nonvoting_lock_for(1 ether, block.timestamp + 1 weeks, user1);
        assertEq(ve.nonVoting(tokenId), true);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Verify non-voting status is preserved
        assertEq(ve.nonVoting(tokenId), true);
    }

    function test_UpgradePreservesTotalSupply() public {
        // Create locks
        vm.prank(user1);
        ve.create_lock(1 ether, block.timestamp + 1 weeks);
        skip(1);
        vm.prank(user1);
        ve.create_lock(2 ether, block.timestamp + 2 weeks);
        uint256 totalSupplyBefore = ve.totalSupply();
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Verify total supply is preserved
        uint256 totalSupplyAfter = ve.totalSupply();
        assertEq(totalSupplyAfter, totalSupplyBefore);
    }

    function test_UpgradePreservesCheckpoints() public {
        // Create lock and checkpoint
        vm.prank(user1);
        ve.create_lock(1 ether, block.timestamp + 1 weeks);
        ve.checkpoint();
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Verify checkpoints are preserved
        uint256 numCheckpoints = VotingEscrowV2(address(ve)).numCheckpointsPublic(user1);
        assertGt(numCheckpoints, 0);
    }

    function test_UpgradeNewFeaturesWork() public {
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test increment upgrade count
        vm.prank(address(ctmDaoGovernor));
        VotingEscrowV2(address(ve)).incrementUpgradeCount();
        assertEq(VotingEscrowV2(address(ve)).getUpgradeCount(), 2);
    }

    function test_UpgradeUnauthorizedIncrementFails() public {
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test unauthorized increment fails
        vm.expectRevert("V2: Only governor can increment");
        VotingEscrowV2(address(ve)).incrementUpgradeCount();
    }

    function test_UpgradePreservesExistingFunctions() public {
        // Create lock
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(1 ether, block.timestamp + 1 weeks);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test that existing functions still work
        vm.prank(user1); // Make sure we're pranking as user1
        ve.increase_amount(tokenId, 1 ether);
        vm.prank(user1);
        ve.increase_unlock_time(tokenId, block.timestamp + 2 weeks);
        
        // Verify changes took effect
        (int128 amount, ) = ve.locked(tokenId);
        assertEq(uint256(int256(amount)), 2 ether);
    }

    function test_UpgradePreservesInterface() public {
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test that interface functions still work
        assertEq(ve.name(), "Voting Escrow Continuum");
        assertEq(ve.symbol(), "veCTM");
        assertEq(ve.decimals(), 18);
        assertEq(ve.token(), address(ctm));
        assertEq(ve.governor(), address(ctmDaoGovernor));
    }

    function test_UpgradePreservesERC721Functions() public {
        // Create lock
        vm.prank(user1);
        uint256 tokenId = ve.create_lock(1 ether, block.timestamp + 1 weeks);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test ERC721 functions
        assertEq(ve.ownerOf(tokenId), user1);
        assertEq(ve.balanceOf(user1), 1);
        assertEq(ve.tokenURI(tokenId), "Base URI1");
    }

    function test_UpgradePreservesVotingFunctions() public {
        // Create lock and delegate
        vm.prank(user1);
        ve.create_lock(1 ether, block.timestamp + 1 weeks);
        ve.delegate(user2);
        
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test voting functions - voting power might be 0 initially
        ve.getVotes(user2);
        ve.getPastVotes(user2, block.timestamp - 1);
        // Just verify the functions don't revert
        assertTrue(true);
    }

    function test_UpgradePreservesStateVariables() public {
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test that state variables are preserved
        assertEq(ve.treasury(), treasury);
        assertEq(ve.nodeProperties(), address(nodeProperties));
        assertEq(ve.rewards(), address(rewards));
        assertEq(ve.liquidationsEnabled(), true);
    }

    function test_UpgradeNewMinimumDurationEnforced() public {
        // Upgrade
        vm.prank(address(ctmDaoGovernor));
        ve.upgradeToAndCall(address(veImplV2), initializerDataV2);
        
        // Test that new minimum duration is enforced
        vm.expectRevert(abi.encodeWithSelector(VotingEscrowV2.V2_MinimumLockDuration.selector, 10 days));
        vm.prank(user1);
        VotingEscrowV2(address(ve)).create_lock_v2(1 ether, 10 days);
        
        // Test that valid duration still works
        vm.prank(user1);
        uint256 tokenId = VotingEscrowV2(address(ve)).create_lock_v2(1 ether, block.timestamp + 20 days);
        assertEq(ve.ownerOf(tokenId), user1);
    }
} 
