# GovernorCountingAdvanced

## API Reference

```
enum ProposalType {
	Basic,
	SingleChoice,
	Approval,
	Weighted
}
```

The voting type options when creating a new vote.

```
function _countVote(
	uint256 proposalId,
	address account,
	uint8 support,
	uint256 weight,
	bytes memory
) internal virtual override;
```

This function is called by `castVote` when a DAO member casts their vote. It contains their support, the type of which is based on the type of vote. The type of the proposal is checked (either basic, single choice, approval, or weighted) and the vote is cast accordingly.

```
function _basicVote(
	uint256 proposalId,
	address account,
	uint8 support,
	uint256 weight
) internal virtual;
```

Cast a basic vote, with `support` being either For, Against, or Abstain.

```
function _weightedVote(
	uint256 proposalId,
	address account,
	uint8 support,
	uint256 weight,
	uint8 allocated
) internal virtual;
```

Cast a weighted vote, with `support` being a number between 0 and 100 for the percentage of the `account`'s voting power they wish to cast on this option.

```
function proposeAdvanced
	GovernorCountingAdvanced.ProposalType proposalType,
	Proposal[] memory proposals,
	string memory description
) public returns (uint256[] memory proposalIds);
```

Create a vote that can be either basic or advanced type. This is comprised of one or multiple "basic" proposals, depending on the vote type.