# Snapshot API

The snapshot system allows capturing historical balance states for governance, auditing, and analytics purposes. Snapshots record both transferable and locked token balances at specific points in time.

## Core Concepts

### Snapshot Structure

Snapshots capture:

- Total supply at snapshot time
- Individual address balances (including locked tokens)
- Timestamp of snapshot creation
- List of addresses included in snapshot

### Storage System

```solidity
mapping(uint256 => uint256) public snapshotTotalSupply;
mapping(uint256 => uint256) public snapshotTimestamp;
mapping(uint256 => mapping(address => uint256)) public snapshotBalances;
mapping(uint256 => address[]) public snapshotAddresses;
uint256 public currentSnapshotId;
```

## Snapshot Creation Functions

### `snapshot()`

Creates a new snapshot of all registered addresses with balances.

```solidity
function snapshot() public onlyOwner returns (uint256)
```

**Returns:** The ID of the newly created snapshot

**Process:**

1. Increments snapshot ID
2. Records current total supply and timestamp
3. Iterates through all registered addresses
4. Stores balances for addresses with non-zero balances
5. Emits `SnapshotCreated` event

**Gas Optimization:** Only addresses with positive balances are included

**Example:**

```solidity
// Create snapshot for governance voting
uint256 snapshotId = lockToken.snapshot();
console.log("Created snapshot", snapshotId, "for voting");
```

**Event Emitted:**

```solidity
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
```

### `addAddressToSnapshot()`

Manually adds a specific address to an existing snapshot.

```solidity
function addAddressToSnapshot(address _address, uint256 snapshotId) public onlyOwner
```

**Parameters:**

- `_address`: Address to add to the snapshot
- `snapshotId`: ID of the existing snapshot

**Requirements:**

- Address cannot be zero address
- Snapshot must exist
- Address must have positive balance

**Use Cases:**

- Adding addresses that were missed in initial snapshot
- Including specific addresses for targeted governance
- Correcting snapshot data

**Example:**

```solidity
// Add specific address to existing snapshot
lockToken.addAddressToSnapshot(newHolderAddress, snapshotId);
```

### `addAddressesToSnapshot()`

Batch adds multiple addresses to an existing snapshot.

```solidity
function addAddressesToSnapshot(address[] memory _addresses, uint256 snapshotId) public onlyOwner
```

**Parameters:**

- `_addresses`: Array of addresses to add
- `snapshotId`: ID of the existing snapshot

**Features:**

- Batch processing for gas efficiency
- Automatically skips zero addresses
- Only includes addresses with positive balances

**Example:**

```solidity
// Batch add multiple addresses
address[] memory newHolders = new address[](3);
newHolders[0] = address1;
newHolders[1] = address2;
newHolders[2] = address3;

lockToken.addAddressesToSnapshot(newHolders, snapshotId);
```

## Snapshot Query Functions

### `balanceOfAt()`

Returns the balance of an address at a specific snapshot.

```solidity
function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256)
```

**Parameters:**

- `account`: Address to query
- `snapshotId`: Snapshot ID to query

**Returns:** Token balance at the time of snapshot (includes locked tokens)

**Example:**

```solidity
// Check voting power at snapshot
uint256 votingPower = lockToken.balanceOfAt(voter, governanceSnapshotId);
if (votingPower >= minimumVotingPower) {
    // Allow voting
}
```

### `getSnapshotTotalSupply()`

Returns the total supply recorded at a specific snapshot.

```solidity
function getSnapshotTotalSupply(uint256 snapshotId) public view returns (uint256)
```

**Use Cases:**

- Calculating percentage ownership
- Market cap calculations at specific times
- Supply analysis over time

**Example:**

```solidity
uint256 totalSupply = lockToken.getSnapshotTotalSupply(snapshotId);
uint256 userBalance = lockToken.balanceOfAt(user, snapshotId);
uint256 ownershipPercent = (userBalance * 100) / totalSupply;
```

### `getSnapshotTimestamp()`

Returns the timestamp when a snapshot was created.

```solidity
function getSnapshotTimestamp(uint256 snapshotId) public view returns (uint256)
```

**Example:**

```solidity
uint256 timestamp = lockToken.getSnapshotTimestamp(snapshotId);
console.log("Snapshot created at:", timestamp);
```

### `getSnapshotAddresses()`

Returns all addresses included in a specific snapshot.

```solidity
function getSnapshotAddresses(uint256 snapshotId) public view returns (address[] memory)
```

**Returns:** Array of addresses that had balances at snapshot time

**Use Cases:**

- Airdrop distribution lists
- Governance participant lists
- Historical holder analysis

**Example:**

```solidity
address[] memory holders = lockToken.getSnapshotAddresses(snapshotId);
console.log("Snapshot contains", holders.length, "holders");

for (uint i = 0; i < holders.length; i++) {
    uint256 balance = lockToken.balanceOfAt(holders[i], snapshotId);
    console.log("Holder", holders[i], "had", balance, "tokens");
}
```

### `getSnapshotAddressCount()`

Returns the number of addresses in a specific snapshot.

```solidity
function getSnapshotAddressCount(uint256 snapshotId) public view returns (uint256)
```

**Gas Efficient:** Returns count without loading full address array

**Example:**

```solidity
uint256 holderCount = lockToken.getSnapshotAddressCount(snapshotId);
console.log("Snapshot has", holderCount, "unique holders");
```

### `isAddressInSnapshot()`

Checks if a specific address is included in a snapshot.

```solidity
function isAddressInSnapshot(address _address, uint256 snapshotId) public view returns (bool)
```

**Parameters:**

- `_address`: Address to check
- `snapshotId`: Snapshot ID to check

**Example:**

```solidity
bool canVote = lockToken.isAddressInSnapshot(voter, governanceSnapshotId);
require(canVote, "Address not eligible for this vote");
```

## Advanced Usage Patterns

### Governance Integration

```solidity
// Governance contract integration
contract TokenGovernance {
    LockToken public immutable token;
    uint256 public proposalSnapshotId;

    function createProposal() external {
        // Create snapshot for voting
        proposalSnapshotId = token.snapshot();
    }

    function vote(bool support) external {
        uint256 votingPower = token.balanceOfAt(msg.sender, proposalSnapshotId);
        require(votingPower > 0, "No voting power");

        // Record vote with weight = votingPower
    }
}
```

### Airdrop Distribution

```solidity
// Airdrop based on snapshot
contract AirdropDistributor {
    function distributeAirdrop(uint256 snapshotId) external {
        address[] memory holders = lockToken.getSnapshotAddresses(snapshotId);
        uint256 totalSupply = lockToken.getSnapshotTotalSupply(snapshotId);

        for (uint i = 0; i < holders.length; i++) {
            uint256 balance = lockToken.balanceOfAt(holders[i], snapshotId);
            uint256 airdropAmount = (balance * AIRDROP_TOTAL) / totalSupply;

            // Distribute proportional airdrop
            airdropToken.transfer(holders[i], airdropAmount);
        }
    }
}
```

### Historical Analysis

```solidity
// Analyze holder distribution over time
function analyzeHolderGrowth(uint256[] memory snapshotIds) external view returns (
    uint256[] memory holderCounts,
    uint256[] memory totalSupplies
) {
    holderCounts = new uint256[](snapshotIds.length);
    totalSupplies = new uint256[](snapshotIds.length);

    for (uint i = 0; i < snapshotIds.length; i++) {
        holderCounts[i] = lockToken.getSnapshotAddressCount(snapshotIds[i]);
        totalSupplies[i] = lockToken.getSnapshotTotalSupply(snapshotIds[i]);
    }
}
```

## Gas Optimization

### Efficient Address Selection

Only addresses with positive balances are included:

```solidity
for (uint256 i = 0; i < addressCount; i++) {
    address addr = addressList[i];
    uint256 balance = balanceOf(addr);
    if (balance > 0) {  // Only non-zero balances
        snapshotBalances[snapshotId][addr] = balance;
        snapshotAddrList.push(addr);
    }
}
```

### Batch Processing

Use `addAddressesToSnapshot()` for multiple addresses to save gas:

```solidity
// Efficient: Single transaction
lockToken.addAddressesToSnapshot(addressArray, snapshotId);

// Inefficient: Multiple transactions
for (uint i = 0; i < addresses.length; i++) {
    lockToken.addAddressToSnapshot(addresses[i], snapshotId);
}
```

## Snapshot Events

```solidity
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
```

**Event Parameters:**

- `snapshotId`: Unique identifier for the snapshot
- `totalAddresses`: Number of addresses included in snapshot
- `totalSupply`: Total token supply at snapshot time

## Security Considerations

### Access Control

- Only contract owner can create snapshots
- Only owner can add addresses to existing snapshots
- All query functions are publicly accessible

### Data Integrity

- Snapshots are immutable once created
- Balance data reflects state at exact snapshot block
- Includes both transferable and locked token balances

### Gas Limits

- Large snapshots may hit gas limits
- Consider batch processing for very large holder sets
- Monitor gas usage during snapshot creation

## Error Messages

| Error                        | Cause                                    |
| ---------------------------- | ---------------------------------------- |
| `"Cannot add zero address"`  | Attempting to add address(0) to snapshot |
| `"Snapshot does not exist"`  | Invalid snapshot ID                      |
| `"Address has zero balance"` | Adding address with no tokens            |

## Integration Examples

### DeFi Protocol Integration

```solidity
// DEX listing verification
function verifyTokenDistribution(uint256 snapshotId) external view returns (bool) {
    address[] memory holders = lockToken.getSnapshotAddresses(snapshotId);
    uint256 totalSupply = lockToken.getSnapshotTotalSupply(snapshotId);

    // Check if top holder has < 50% of supply
    uint256 maxBalance = 0;
    for (uint i = 0; i < holders.length; i++) {
        uint256 balance = lockToken.balanceOfAt(holders[i], snapshotId);
        if (balance > maxBalance) {
            maxBalance = balance;
        }
    }

    return (maxBalance * 100) / totalSupply < 50; // Less than 50%
}
```

### Staking Rewards

```solidity
// Staking rewards based on historical holdings
function calculateStakingRewards(address user, uint256 fromSnapshot, uint256 toSnapshot)
    external view returns (uint256) {

    uint256 totalRewards = 0;

    for (uint256 id = fromSnapshot; id <= toSnapshot; id++) {
        uint256 balance = lockToken.balanceOfAt(user, id);
        uint256 dailyReward = (balance * DAILY_RATE) / 10000;
        totalRewards += dailyReward;
    }

    return totalRewards;
}
```

## Best Practices

### 1. **Regular Snapshots**

- Create snapshots at regular intervals (daily/weekly)
- Document snapshot purposes and timing
- Maintain snapshot metadata off-chain

### 2. **Governance Usage**

- Create snapshots before proposal announcements
- Allow sufficient time between snapshot and voting
- Clearly communicate snapshot block numbers

### 3. **Gas Management**

- Monitor gas costs for large snapshots
- Consider snapshot frequency vs. gas costs
- Use batch operations when possible

## Next Steps

- [Account Management API](account.md) - User and permission management
- [Events Documentation](events.md) - Complete event reference
