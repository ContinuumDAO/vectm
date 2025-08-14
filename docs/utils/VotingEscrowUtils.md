# VotingEscrowUtils

## Overview

The VotingEscrowUtils contract provides error parameter enumerations used throughout the VotingEscrow system for consistent error reporting and parameter identification.

## Contract Details

- **Contract**: `VotingEscrowUtils.sol`
- **Type**: Utility Contract
- **License**: MIT
- **Solidity Version**: 0.8.27

## Enumerations

### `VotingEscrowErrorParam`

```solidity
enum VotingEscrowErrorParam {
    Sender,
    Admin,
    Owner,
    Governor,
    Value,
    Approved,
    ApprovedOrOwner,
    Implementation,
    Treasury,
    Token,
    Rewards,
    NodeProperties
}
```

This enumeration defines the different types of parameters that can be referenced in error messages throughout the VotingEscrow system.

## Parameter Descriptions

- **Sender**: The address of the transaction sender
- **Admin**: The address of the administrator
- **Owner**: The address of the token owner
- **Governor**: The address of the governance contract
- **Value**: A numeric value parameter
- **Approved**: The address of an approved operator
- **ApprovedOrOwner**: Either an approved operator or the owner
- **Implementation**: The address of the implementation contract
- **Treasury**: The address of the treasury contract
- **Token**: The address of the underlying token
- **Rewards**: The address of the rewards contract
- **NodeProperties**: The address of the node properties contract

## Usage

This enumeration is used throughout the VotingEscrow system to provide consistent and descriptive error messages. When errors occur, the system can reference specific parameters using these enumerated values, making error messages more informative and easier to debug.

### Example Usage

```solidity
// In VotingEscrow contract
if (msg.sender != governor) {
    revert VotingEscrow_OnlyAuthorized(VotingEscrowErrorParam.Sender, VotingEscrowErrorParam.Governor);
}
```

This pattern allows for clear identification of which parameter caused an error, improving the developer experience and debugging capabilities.

## Integration

The VotingEscrowErrorParam enumeration is used by:

- **VotingEscrow**: For error reporting in lock management and delegation functions
- **NodeProperties**: For error reporting in node attachment and management functions
- **Rewards**: For error reporting in reward distribution functions

This centralized approach ensures consistent error reporting across the entire VotingEscrow ecosystem.
