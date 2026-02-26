// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IVotingEscrow} from "./IVotingEscrow.sol";

/**
 * @title Distribution
 * @notice Distribute CTM tokens in the form of 4 year ve locks to the legacy token holders from Continuum's inception.
 * @author @patrickcure
 */
contract Distribution {
    /// @notice Emits whenever someone claims their ve
    event Claim(address indexed _account, uint256 _amount, uint256 indexed _id);

    /// @notice Emits when the claim period has begun - the ledger is now immutable and 90 days remain to claim
    event ClaimsStarted();

    /// @notice Emits when the unclaimed tokens in the 90 day window are transferred to the DAO treasury
    event UnclaimedToTreasury(uint256 _unclaimed);

    /// @notice Only admin function
    error OnlyAdmin();

    /// @notice Claiming window has not yet started
    error ClaimingNotStarted();

    /// @notice Claiming window is now over
    error ClaimingEnded();

    /// @notice Claiming window is currently active
    error ClaimingActive();

    /// @notice Address has already claimed their allocated ve
    error AlreadyClaimed();

    /// @notice Assigning an address CTM puts the total above the maximum
    error AssignmentAboveMaxClaimable(uint256 _balanceAfter);

    /// @notice Admin address
    address public admin;

    /// @notice CTM token address
    address public ctm;

    /// @notice Voting Escrow address
    address public ve;

    /// @notice ContinuumDAO governor address
    address public dao;

    /// @notice Total CTM designated to claimers so far - cumulative
    uint256 public totalClaimable;

    /// @notice Maximum CTM claimable - this does not change
    uint256 public maxClaimable;

    /// @notice Maximum number of addresses eligible to claim - this does not change
    uint256 public maxClaimers;

    /// @notice The amount of CTM claimed so far
    uint256 public claimed;

    /// @notice The number of addresses that have claimed so far
    uint256 public claimers;

    /// @notice UNIX timestamp in seconds representing the cut-off for claiming CTM - starts at zero
    uint256 public deadline;

    /// @notice Claiming window duration: Monday 1st June 2026 00:00:00 UTC
    uint256 public constant CLAIM_DEADLINE = 1780272000;

    /// @notice Max lock time for voting escrow: 4 years
    uint256 public constant FOUR_YEARS = 4 * 365 * 86_400;

    /// @notice Mapping from individual address to the amount of CTM they are able to claim
    mapping(address => uint256) public ctmDue;

    /// @notice Mapping from individual address to whether they have claimed their CTM or not
    mapping(address => bool) public hasClaimed;

    /// @notice Mapping from individual address to the token ID they claimed
    mapping(address => uint256) public claimedId;

    /// @notice Mapping from enumerated claim to token ID
    mapping(uint256 => uint256) public claimToTokenId;

    /// @notice Modifier to restrict a function to only admin
    modifier onlyAdmin() {
        if (msg.sender != admin) revert OnlyAdmin();
        _;
    }

    /**
     * @notice Constructor for CTMDistribution
     * @param _ctm Address of the CTM token
     * @param _ve Address of the Voting Escrow token
     * @param _dao Address of the ContinuumDAO governor
     */
    constructor(address _ctm, address _ve, address _dao, uint256 _maxClaimable) {
        admin = msg.sender;
        ctm = _ctm;
        ve = _ve;
        dao = _dao;
        maxClaimable = _maxClaimable;
        IERC20(_ctm).approve(_ve, _maxClaimable);
    }

    /**
     * @notice Claim CTM: called by eligible addresses
     * @notice Converts the allocated CTM into a maximum lock Voting Escrow NFT
     * @dev Reverts if: claiming not yet started, address has already claimed, claiming has ended.
     */
    function claimCTM() external {
        if (deadline == 0) revert ClaimingNotStarted();
        if (hasClaimed[msg.sender]) revert AlreadyClaimed();
        if (block.timestamp >= deadline) revert ClaimingEnded();
        uint256 _ctmDue = ctmDue[msg.sender];
        hasClaimed[msg.sender] = true;
        if (_ctmDue > 0) {
            uint256 id = IVotingEscrow(ve).create_lock_for(_ctmDue, FOUR_YEARS, msg.sender);
            claimToTokenId[claimers] = id;
            claimers++;
            claimed += _ctmDue;
            claimedId[msg.sender] = id;
            emit Claim(msg.sender, _ctmDue, id);
        }
    }

    /**
     * @notice Set the CTM due for an address. These amounts were determined at DAO inception, and include amounts
     * allocated to those who have contributed to the DAO along the way, according to DAO popular vote.
     * @param _account The address of the account who is due CTM
     * @param _amount The amount of CTM the account is due
     * @dev This function is only admin
     * @dev If the amount being added equals the maxClaimable (and no more) then initiate the claiming period.
     */
    function setCTMDue(address _account, uint256 _amount) external onlyAdmin {
        if (deadline != 0) revert ClaimingActive();
        if (ctmDue[_account] == 0 && _amount != 0) maxClaimers++;
        if (ctmDue[_account] != 0 && _amount == 0) maxClaimers--;
        ctmDue[_account] = _amount;
        totalClaimable += _amount;
        if (totalClaimable > maxClaimable) revert AssignmentAboveMaxClaimable(totalClaimable);
        if (totalClaimable == maxClaimable) {
            deadline = CLAIM_DEADLINE;
            emit ClaimsStarted();
        }
    }

    /**
     * @notice Transfers any CTM that was unclaimed before the deadline to the DAO treasury
     * @dev Only possible after the claiming deadline has ended.
     */
    function settleUnclaimed() external {
        if (block.timestamp < deadline) revert ClaimingActive();
        uint256 _unclaimed = remainingClaimable();
        IERC20(ctm).transfer(dao, _unclaimed);
        emit UnclaimedToTreasury(_unclaimed);
    }

    /**
     * @notice Calculates the remaining claimable CTM as difference between initial total claimable and claimed so far.
     * @return The remaining claimable CTM by those who have not yet done so.
     */
    function remainingClaimable() public view returns (uint256) {
        return maxClaimable - claimed;
    }

    /**
     * @notice Calculates the remaining number of addresses that can claim CTM as difference between initial total
     * claimers and claims so far.
     * @return The remaining number of CTM claims possible.
     */
    function remainingClaimers() public view returns (uint256) {
        return maxClaimers - claimers;
    }
}
