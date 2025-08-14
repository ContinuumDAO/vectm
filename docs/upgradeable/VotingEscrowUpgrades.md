# VotingEscrow Upgrades

## Overview

The VotingEscrow contract implements the UUPS (Universal Upgradeable Proxy Standard) pattern using ERC1967 for secure and efficient upgrades. This document details the upgrade process, architecture, and procedures for upgrading the VotingEscrow implementation while maintaining state and functionality.

## Architecture

### UUPS Pattern Implementation

The VotingEscrow upgrade system consists of three main components:

1. **VotingEscrow Implementation Contract** (`VotingEscrow.sol`)
   - Contains the actual logic and functionality
   - Inherits from `UUPSUpgradeable`
   - Can be upgraded while maintaining state

2. **VotingEscrowProxy Contract** (`VotingEscrowProxy.sol`)
   - ERC1967 proxy that delegates calls to the implementation
   - Maintains all state and storage
   - Provides upgrade functionality

3. **Governance Contract** (`CTMDAOGovernor.sol`)
   - Controls upgrade authorization
   - Only governance can initiate upgrades

### Storage Layout

The UUPS pattern ensures that:
- **State variables** are stored in the proxy contract
- **Logic** is executed in the implementation contract
- **Upgrade functionality** is embedded in the implementation
- **Storage slots** are preserved across upgrades

## Upgrade Authorization

### `_authorizeUpgrade(address newImplementation) internal view override onlyGov`

The upgrade authorization function controls who can perform upgrades.

**Parameters:**
- `newImplementation` (address): The address of the new implementation contract

**Behavior:**
- Validates that the new implementation address is not zero
- Only allows governance to authorize upgrades
- Reverts with `VotingEscrow_IsZeroAddress` if implementation is zero
- Reverts with `VotingEscrow_OnlyAuthorized` if caller is not governance

**Access Control:**
- Only governance can authorize upgrades
- Uses `onlyGov` modifier for access control

## Upgrade Process

### Step 1: Prepare New Implementation

1. **Deploy New Implementation**
   ```solidity
   // Deploy the new VotingEscrow implementation
   VotingEscrow newImplementation = new VotingEscrow();
   ```

2. **Verify Implementation**
   - Ensure the new implementation is compatible with existing storage layout
   - Verify that all state variables maintain their storage slots
   - Test the new implementation thoroughly

### Step 2: Authorize Upgrade

1. **Governance Proposal**
   - Create a governance proposal to upgrade the implementation
   - Include the new implementation address
   - Specify any initialization data if required

2. **Vote and Execute**
   - Governance votes on the upgrade proposal
   - Upon approval, the upgrade is executed

### Step 3: Execute Upgrade

The upgrade can be performed using one of two methods:

#### Method 1: `upgradeTo(address newImplementation)`

**Parameters:**
- `newImplementation` (address): The address of the new implementation

**Behavior:**
- Updates the implementation address in the proxy
- No initialization data is passed
- All existing state is preserved

#### Method 2: `upgradeToAndCall(address newImplementation, bytes memory data)`

**Parameters:**
- `newImplementation` (address): The address of the new implementation
- `data` (bytes): Initialization data to call on the new implementation

**Behavior:**
- Updates the implementation address in the proxy
- Calls the new implementation with the provided data
- Useful for one-time initialization after upgrade

## Implementation Contract Structure

### Constructor

```solidity
constructor() {
    _disableInitializers();
}
```

**Purpose:**
- Disables initializers for the implementation contract
- Prevents the implementation from being initialized directly
- Ensures only the proxy can be initialized

### Initializer

```solidity
function initialize(address token_addr, string memory base_uri) external initializer {
    __UUPSUpgradeable_init();
    // ... initialization logic
}
```

**Purpose:**
- Initializes the contract when deployed as a proxy
- Can only be called once due to `initializer` modifier
- Sets up the UUPS upgradeable functionality

## Storage Considerations

### State Variable Preservation

All state variables must maintain their storage slots across upgrades:

```solidity
// Core addresses (slots 0-4)
address public token;
address public governor;
address public nodeProperties;
address public rewards;
address public treasury;

// Global state (slots 5-10)
uint256 public epoch;
string public baseURI;
uint8 internal _entered_state;
uint256 internal _supply;
uint256 internal tokenId;
uint256 internal _totalSupply;

// Mappings (slots 11+)
mapping(uint256 => LockedBalance) public locked;
mapping(uint256 => uint256) public ownership_change;
// ... additional mappings
```

### Storage Layout Rules

1. **Never change the order** of existing state variables
2. **Never remove** existing state variables
3. **Only append** new state variables at the end
4. **Use storage gaps** for future upgrades if needed
5. **Maintain mapping keys** and structure

## Upgrade Safety Checks

### Pre-Upgrade Validation

1. **Storage Layout Verification**
   - Ensure new implementation maintains storage layout
   - Verify all state variables are preserved
   - Check mapping structures remain unchanged

2. **Function Signature Compatibility**
   - Verify all public/external function signatures
   - Ensure return types remain the same
   - Check parameter types and order

3. **Event Compatibility**
   - Ensure all events are preserved
   - Verify event parameter types
   - Check indexed parameters

### Post-Upgrade Validation

1. **State Verification**
   - Verify all existing state is preserved
   - Check that mappings contain expected data
   - Validate token ownership and balances

2. **Functionality Testing**
   - Test all core functions
   - Verify delegation mechanisms
   - Check reward calculations

## Governance Integration

### Upgrade Authorization Flow

1. **Proposal Creation**
   ```solidity
   // Governance creates upgrade proposal
   governor.propose(
       [votingEscrowProxy],
       [0], // no ETH value
       [upgradeCalldata],
       "Upgrade VotingEscrow to v2.0"
   );
   ```

2. **Voting Period**
   - veCTM token holders vote on the upgrade
   - Requires quorum and majority approval

3. **Execution**
   ```solidity
   // Execute upgrade after governance approval
   votingEscrowProxy.upgradeTo(newImplementation);
   ```

### Governance Controls

- **Only governance** can authorize upgrades
- **Multi-signature** approval required
- **Timelock** protection for critical upgrades
- **Emergency pause** capability if needed

## Security Considerations

### Upgrade Risks

1. **Storage Collision**
   - **Risk**: New implementation changes storage layout
   - **Mitigation**: Strict storage layout rules and testing

2. **Function Signature Changes**
   - **Risk**: Breaking changes to public interfaces
   - **Mitigation**: Maintain backward compatibility

3. **Logic Errors**
   - **Risk**: Bugs in new implementation
   - **Mitigation**: Extensive testing and audits

4. **Governance Attack**
   - **Risk**: Malicious governance upgrade
   - **Mitigation**: Multi-signature and timelock protection

### Security Best Practices

1. **Thorough Testing**
   - Unit tests for all functions
   - Integration tests with existing state
   - Upgrade simulation tests

2. **Audit Requirements**
   - Security audit of new implementation
   - Storage layout verification
   - Upgrade process review

3. **Emergency Procedures**
   - Emergency pause functionality
   - Rollback procedures
   - Governance emergency controls

## Upgrade Procedures

### Standard Upgrade Process

1. **Development Phase**
   - Develop and test new implementation
   - Verify storage layout compatibility
   - Conduct security audit

2. **Governance Proposal**
   - Create upgrade proposal
   - Include implementation address and verification
   - Set appropriate voting period

3. **Community Review**
   - Allow community review period
   - Address any concerns or issues
   - Provide upgrade documentation

4. **Voting and Execution**
   - Execute governance vote
   - Deploy new implementation
   - Execute upgrade transaction

5. **Post-Upgrade Verification**
   - Verify state preservation
   - Test core functionality
   - Monitor for issues

### Emergency Upgrade Process

1. **Emergency Detection**
   - Identify critical vulnerability
   - Assess impact and urgency
   - Prepare emergency fix

2. **Emergency Governance**
   - Use emergency governance procedures
   - Expedited voting if necessary
   - Immediate execution

3. **Post-Emergency Review**
   - Full audit of emergency fix
   - Community communication
   - Lessons learned documentation

## Monitoring and Maintenance

### Upgrade Tracking

1. **Implementation Registry**
   - Track all implementation versions
   - Maintain upgrade history
   - Document changes and rationale

2. **Performance Monitoring**
   - Monitor gas usage changes
   - Track function performance
   - Identify optimization opportunities

3. **Security Monitoring**
   - Monitor for security issues
   - Track vulnerability reports
   - Maintain security contact information

### Maintenance Procedures

1. **Regular Reviews**
   - Quarterly security reviews
   - Annual upgrade planning
   - Community feedback collection

2. **Documentation Updates**
   - Update upgrade procedures
   - Maintain change logs
   - Keep community informed

3. **Testing Procedures**
   - Automated upgrade testing
   - Manual verification procedures
   - Disaster recovery testing

## Example Upgrade Implementation

### New Implementation Contract

```solidity
// VotingEscrowV2.sol
contract VotingEscrowV2 is VotingEscrow {
    // New state variables (appended to end)
    uint256 public newFeature;
    
    // Override existing functions
    function newFunction() external view returns (uint256) {
        return newFeature;
    }
    
    // Maintain all existing functionality
    // Ensure storage layout compatibility
}
```

### Upgrade Execution

```solidity
// Governance proposal execution
function executeUpgrade() external onlyGov {
    // 1. Deploy new implementation
    VotingEscrowV2 newImpl = new VotingEscrowV2();
    
    // 2. Authorize upgrade
    votingEscrow._authorizeUpgrade(address(newImpl));
    
    // 3. Execute upgrade
    votingEscrow.upgradeTo(address(newImpl));
}
```

## Conclusion

The VotingEscrow upgrade system provides a secure and efficient way to evolve the contract while maintaining state and functionality. The UUPS pattern with ERC1967 ensures that upgrades are controlled, verifiable, and safe for users.

Key principles for successful upgrades:
- **Maintain storage layout compatibility**
- **Preserve all existing functionality**
- **Follow governance procedures**
- **Conduct thorough testing and audits**
- **Monitor and verify post-upgrade state**
