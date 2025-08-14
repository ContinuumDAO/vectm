# CTM Token

## Overview

The CTM (Continuum) token is the native ERC20 token of the ContinuumDAO ecosystem. It serves as the underlying asset that can be locked in the voting escrow system to receive veCTM NFTs with voting power.

## Contract Details

- **Contract**: `CTM.sol`
- **Inherits**: `ERC20` from OpenZeppelin
- **License**: GPL-3.0-or-later
- **Solidity Version**: 0.8.27

## State Variables

The contract inherits all standard ERC20 state variables from OpenZeppelin's ERC20 implementation.

## Constructor

### `constructor(address _admin)`

Initializes the CTM token with the specified admin address.

**Parameters:**
- `_admin` (address): The address that will receive the initial token supply

**Behavior:**
- Sets the token name to "Continuum"
- Sets the token symbol to "CTM"
- Mints 100,000,000 CTM tokens (with 18 decimals) to the admin address
- The total supply is fixed at deployment

**Events Emitted:**
- `Transfer(address(0), _admin, 100_000_000 ether)` - Initial mint event

## Functions

### `burn(uint256 _amount) external`

Allows the caller to burn (destroy) their own CTM tokens.

**Parameters:**
- `_amount` (uint256): The amount of CTM tokens to burn

**Behavior:**
- Burns the specified amount of tokens from the caller's balance
- Reduces the total supply by the burned amount
- Reverts if the caller has insufficient balance

**Events Emitted:**
- `Transfer(msg.sender, address(0), _amount)` - Burn event

**Access Control:**
- Public function - any address can call this function to burn their own tokens

## ERC20 Interface

The contract implements the standard ERC20 interface with the following functions inherited from OpenZeppelin:

- `transfer(address to, uint256 amount)` - Transfer tokens to another address
- `transferFrom(address from, address to, uint256 amount)` - Transfer tokens on behalf of another address
- `approve(address spender, uint256 amount)` - Approve another address to spend tokens
- `allowance(address owner, address spender)` - Get the allowance for a spender
- `balanceOf(address account)` - Get the balance of an account
- `totalSupply()` - Get the total supply of tokens
- `name()` - Get the token name ("Continuum")
- `symbol()` - Get the token symbol ("CTM")
- `decimals()` - Get the token decimals (18)

## Usage

The CTM token is primarily used as:

1. **Locking Asset**: Users lock CTM tokens in the VotingEscrow contract to receive veCTM NFTs
2. **Reward Token**: CTM is distributed as rewards to veCTM token holders and node operators
3. **Governance**: CTM holders can participate in DAO governance through the voting escrow system
4. **Medium of Exchange**: CTM can be traded and used for various ecosystem activities

## Security Considerations

- The total supply is fixed at deployment (100,000,000 CTM)
- Only the token owner can burn their own tokens
- The contract uses OpenZeppelin's battle-tested ERC20 implementation
- No minting function exists after deployment, ensuring supply control
