# veCTM

## Second Draft

### Upgradeability

- Revise the UUPS upgradeable smart contracts.
- Write some tests (fuzz).

### Voting Escrow Core Logic

- Revise ve against Solidly code.
- Test core logic separate from added logic.

### Voting Escrow Added Logic

- Thoroughly test the added logic (fuzz).
- Try and break it!

### Governance Added Logic

- Test OZ Governor's added implications to ve (vote counting etc).
- Try and break it!

### Extras - Rewards & NodeProperties

- Iron out the details of these contracts.
- Thoroughly test any critical implications of interacting with ve.




### Questions

1. What license to use? (Currently GPL-3.0-or-later)
2. What version of solc to use? (Currently ^0.8.23)
3. What chain are we deploying on? (think of gas, decentralization)
4. Should we use a TimelockController?


### To-do

1. Cross-check VotingEscrow with Solidly
2. Cross-check ArrayCheckpoints with OZ Checkpoints
3. Apply the order in IVotingEscrow to VotingEscrow; ie. group functions by module.


### Done

1. Check the outward facing functions (public & external values)... done
2. Group functions by module, not mutability/visibility! Use the latter as a secondary grouping mechanism... done