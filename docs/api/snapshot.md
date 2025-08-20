# Snapshot API

The EDENA Token V2 features an advanced **batch snapshot system** designed to solve gas limit issues and provide accurate historical balance tracking. The system supports large-scale snapshots through batch processing while maintaining data integrity with pause/unpause mechanisms.

## Core Concepts

### Batch Processing Architecture

Unlike traditional snapshot systems that can fail due to gas limits, our system uses batch processing:

- **Batch Creation**: Snapshots are processed in configurable batches (default: 100 addresses per batch)
- **Pause Protection**: Contract is paused during snapshot processing to ensure data consistency
- **Resume Capability**: Interrupted snapshots can be resumed from where they left off
- **Gas Optimization**: Avoids DoS attacks and gas limit failures

### Storage System

```solidity
// Core snapshot data (compatible with original layout)
mapping(uint256 => uint256) public snapshotTotalSupply;
mapping(uint256 => uint256) public snapshotTimestamp;
mapping(uint256 => mapping(address => uint256)) public snapshotBalances;
uint256 public currentSnapshotId;

// Address management
address[] public addressList;
mapping(address => bool) public isAddressRegistered;
mapping(uint256 => address[]) public snapshotAddresses;

// Batch processing state
uint256[] private _allSnapshotIds;
mapping(uint256 => bool) public snapshotCompleted;
mapping(uint256 => uint256) public snapshotProcessedIndex;
mapping(uint256 => bool) public snapshotProcessing;
uint256 public defaultBatchSize;
```

**Key Features:**

- ✅ **UUPS Upgrade Compatible**: Maintains exact storage layout compatibility
- ✅ **Batch Processing**: Handles large address lists without gas issues
- ✅ **Pause Protection**: Ensures snapshot data integrity
- ✅ **Direct Access**: O(1) balance queries after completion

## Snapshot Creation Functions

### `createSnapshot()`

Creates a new snapshot and automatically starts batch processing.

```solidity
function createSnapshot() public onlyOwner returns (uint256)
```

**Returns:** The ID of the newly created snapshot

**Process:**

1. Increments snapshot ID and adds to `_allSnapshotIds`
2. Records current total supply and timestamp
3. Initializes batch processing state
4. **Pauses contract** to prevent token transfers during processing
5. Automatically starts processing with `defaultBatchSize`
6. **Unpauses contract** if processing completes in first batch

**Example:**

```solidity
// Create snapshot for governance voting
uint256 snapshotId = lockToken.createSnapshot();

// Check if completed (small holder set)
bool isCompleted = lockToken.isSnapshotCompleted(snapshotId);
if (isCompleted) {
    console.log("Snapshot completed in single transaction");
} else {
    console.log("Snapshot requires additional processing");
}
```

**Events Emitted:**

```solidity
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
event SnapshotProcessingStarted(uint256 indexed snapshotId);
// If completed immediately:
event SnapshotCompleted(uint256 indexed snapshotId, uint256 totalAddresses);
```

### `processSnapshot()`

Continues batch processing for an existing snapshot.

```solidity
function processSnapshot(uint256 snapshotId, uint256 batchSize) public onlyOwner returns (bool completed)
```

**Parameters:**

- `snapshotId`: ID of the snapshot to process
- `batchSize`: Number of addresses to process (max 200 for safety)

**Returns:** `true` if snapshot processing is completed

**Requirements:**

- Snapshot must exist and be in processing state
- Batch size must be between 1 and 200

**Example:**

```solidity
// Process 50 addresses at a time
uint256 snapshotId = 1;
bool completed = lockToken.processSnapshot(snapshotId, 50);

if (completed) {
    console.log("Snapshot processing completed");
} else {
    console.log("More batches needed");
}
```

### `continueSnapshot()`

Convenience function to continue processing with default batch size.

```solidity
function continueSnapshot(uint256 snapshotId) external onlyOwner returns (bool completed)
```

**Example:**

```solidity
// Continue with default batch size (100)
bool completed = lockToken.continueSnapshot(snapshotId);
```

### `setDefaultBatchSize()`

Configure the default batch size for automatic processing.

```solidity
function setDefaultBatchSize(uint256 _batchSize) external onlyOwner
```

**Parameters:**

- `_batchSize`: New default batch size (1-200)

**Example:**

```solidity
// Set smaller batches for gas optimization
lockToken.setDefaultBatchSize(50);
```

## Snapshot Management Functions

### `finalizeSnapshot()`

Prevents further modifications to a completed snapshot.

```solidity
function finalizeSnapshot(uint256 snapshotId) public onlyOwner
```

**Requirements:**

- Snapshot must be completed before finalization
- Snapshot must not be already finalized

**Use Cases:**

- Lock voting snapshots for governance
- Audit trail compliance
- Prevent accidental data modification

**Example:**

```solidity
// Finalize snapshot before voting starts
if (lockToken.isSnapshotCompleted(snapshotId)) {
    lockToken.finalizeSnapshot(snapshotId);
}
```

### `resetSnapshotProcessing()`

**⚠️ Emergency Function**: Completely resets snapshot processing state.

```solidity
function resetSnapshotProcessing(uint256 snapshotId) external onlyOwner
```

**Warning:** This is an expensive operation that clears all partial snapshot data.

**Use Cases:**

- Recover from processing errors
- Cancel snapshot creation
- Reset corrupted state

**Example:**

```solidity
// Emergency reset if snapshot processing fails
lockToken.resetSnapshotProcessing(snapshotId);
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

**Requirements:**

- Snapshot must be completed

**Performance:** Direct O(1) access to snapshot data

**Example:**

```solidity
// Check voting power at snapshot
address voter = 0x1234...;
uint256 votingPower = lockToken.balanceOfAt(voter, governanceSnapshotId);

if (votingPower >= minimumVotingPower) {
    // Allow voting
    console.log("Voter has", votingPower, "voting power");
}
```

### `getSnapshotTotalSupply()`

Returns the total supply recorded at a specific snapshot.

```solidity
function getSnapshotTotalSupply(uint256 snapshotId) public view returns (uint256)
```

**Example:**

```solidity
uint256 totalSupply = lockToken.getSnapshotTotalSupply(snapshotId);
uint256 userBalance = lockToken.balanceOfAt(user, snapshotId);
uint256 ownershipPercent = (userBalance * 100) / totalSupply;
```

### `getSnapshotTimestamp()`

Returns when a snapshot was created.

```solidity
function getSnapshotTimestamp(uint256 snapshotId) public view returns (uint256)
```

### `getAllSnapshotIds()`

Returns all created snapshot IDs.

```solidity
function getAllSnapshotIds() public view returns (uint256[] memory)
```

**Example:**

```solidity
uint256[] memory allSnapshots = lockToken.getAllSnapshotIds();
console.log("Total snapshots created:", allSnapshots.length);
```

### `getAccountSnapshotIds()`

Returns snapshot IDs where an account has recorded balances.

```solidity
function getAccountSnapshotIds(address account) public view returns (uint256[] memory)
```

**Implementation:** Iterates through all snapshots and checks for balance > 0

**Example:**

```solidity
uint256[] memory userSnapshots = lockToken.getAccountSnapshotIds(voterAddress);
for (uint i = 0; i < userSnapshots.length; i++) {
    uint256 snapshotId = userSnapshots[i];
    uint256 balance = lockToken.balanceOfAt(voterAddress, snapshotId);
    console.log("Snapshot", snapshotId, "balance:", balance);
}
```

## Snapshot Status Functions

### `getSnapshotStatus()`

Returns comprehensive status information for a snapshot.

```solidity
function getSnapshotStatus(uint256 snapshotId) external view returns (
    bool completed,
    uint256 processedCount,
    uint256 totalCount,
    uint256 progressPercentage,
    bool isProcessing,
    bool isFinalized
)
```

**Returns:**

- `completed`: Whether snapshot processing is complete
- `processedCount`: Number of addresses processed
- `totalCount`: Total number of registered addresses
- `progressPercentage`: Processing progress (0-100)
- `isProcessing`: Whether currently in processing state
- `isFinalized`: Whether snapshot is finalized

**Example:**

```solidity
(
    bool completed,
    uint256 processed,
    uint256 total,
    uint256 progress,
    bool processing,
    bool finalized
) = lockToken.getSnapshotStatus(snapshotId);

console.log("Snapshot", snapshotId, ":", progress, "% complete");
console.log("Processed", processed, "of", total, "addresses");
```

### `getSnapshotProgress()`

Returns processing progress information.

```solidity
function getSnapshotProgress(uint256 snapshotId) external view returns (
    uint256 processedAddresses,
    uint256 totalAddresses,
    uint256 remainingAddresses
)
```

### `isSnapshotCompleted()`

Quick check if snapshot is completed.

```solidity
function isSnapshotCompleted(uint256 snapshotId) external view returns (bool)
```

### `isSnapshotProcessing()`

Check if snapshot is currently being processed.

```solidity
function isSnapshotProcessing(uint256 snapshotId) external view returns (bool)
```

## Emergency Functions

### `resumeSnapshotProcessing()`

Resume processing for a snapshot that was stopped.

```solidity
function resumeSnapshotProcessing(uint256 snapshotId) external onlyOwner
```

**Use Cases:**

- Resume after contract upgrade
- Continue after manual pause
- Recover from processing interruption

### `cancelSnapshotProcessing()`

Cancel processing and unpause contract without resetting data.

```solidity
function cancelSnapshotProcessing(uint256 snapshotId) external onlyOwner
```

**Note:** This doesn't reset processed data, just stops processing and unpauses.

## Advanced Usage Patterns

### Large-Scale Governance

```solidity
// Handle large governance snapshots
contract LargeTokenGovernance {
    LockToken public immutable token;
    uint256 public proposalSnapshotId;

    function createProposal() external {
        // Create snapshot (may require multiple transactions)
        proposalSnapshotId = token.createSnapshot();

        // Set up batch processing loop
        _processSnapshotLoop();
    }

    function _processSnapshotLoop() internal {
        while (!token.isSnapshotCompleted(proposalSnapshotId)) {
            bool completed = token.continueSnapshot(proposalSnapshotId);
            if (!completed) {
                // Schedule next batch (could be done off-chain)
                // This prevents hitting gas limits
                break;
            }
        }
    }

    function vote(bool support) external {
        require(token.isSnapshotCompleted(proposalSnapshotId), "Snapshot not ready");

        uint256 votingPower = token.balanceOfAt(msg.sender, proposalSnapshotId);
        require(votingPower > 0, "No voting power");

        // Record vote with weight = votingPower
    }
}
```

### Batch Processing Monitor

```solidity
// Monitor and auto-continue snapshot processing
contract SnapshotProcessor {
    LockToken public immutable token;

    function monitorAndProcess(uint256 snapshotId) external {
        require(token.isSnapshotProcessing(snapshotId), "Not processing");

        while (!token.isSnapshotCompleted(snapshotId)) {
            (
                bool completed,
                uint256 processed,
                uint256 total,
                uint256 progress,
                ,
            ) = token.getSnapshotStatus(snapshotId);

            console.log("Progress:", progress, "% (", processed, "/", total, ")");

            if (!completed) {
                bool batchCompleted = token.continueSnapshot(snapshotId);
                if (!batchCompleted) {
                    // Continue in next transaction to avoid gas limits
                    break;
                }
            }
        }
    }
}
```

### Airdrop Distribution

```solidity
// Safe airdrop based on completed snapshot
contract SnapshotAirdrop {
    function distributeAirdrop(uint256 snapshotId) external {
        require(lockToken.isSnapshotCompleted(snapshotId), "Snapshot not completed");

        uint256[] memory snapshots = new uint256[](1);
        snapshots[0] = snapshotId;

        // Get all addresses from snapshot
        address[] memory addresses = lockToken.getRegisteredAddresses();
        uint256 totalSupply = lockToken.getSnapshotTotalSupply(snapshotId);

        for (uint i = 0; i < addresses.length; i++) {
            uint256 balance = lockToken.balanceOfAt(addresses[i], snapshotId);
            if (balance > 0) {
                uint256 airdropAmount = (balance * AIRDROP_TOTAL) / totalSupply;
                airdropToken.transfer(addresses[i], airdropAmount);
            }
        }
    }
}
```

## Gas Optimization Features

### Pause/Unpause Mechanism

```solidity
// Automatic pause during processing
function createSnapshot() public onlyOwner returns (uint256) {
    // ... initialization ...

    // Pause only if not already paused
    if (!paused()) {
        _pause();
    }

    // ... processing ...

    // Unpause only if we paused it and processing is complete
    if (completed && paused()) {
        _unpause();
    }
}
```

### Efficient Batch Processing

```solidity
function _processSnapshotInternal(uint256 snapshotId, uint256 batchSize) internal returns (bool) {
    uint256 startIndex = snapshotProcessedIndex[snapshotId];
    uint256 endIndex = startIndex + batchSize;

    if (endIndex > addressList.length) {
        endIndex = addressList.length;
    }

    // Process only addresses with balances
    for (uint256 i = startIndex; i < endIndex; i++) {
        address account = addressList[i];
        uint256 balance = balanceOf(account);

        if (balance > 0) {
            // Prevent duplicates
            if (snapshotBalances[snapshotId][account] == 0) {
                snapshotAddresses[snapshotId].push(account);
            }
            snapshotBalances[snapshotId][account] = balance;
        }
    }

    // Update processed index
    snapshotProcessedIndex[snapshotId] = endIndex;

    return endIndex >= addressList.length;
}
```

## Events

```solidity
// Snapshot lifecycle events
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
event SnapshotProcessingStarted(uint256 indexed snapshotId);
event SnapshotProcessingResumed(uint256 indexed snapshotId);
event SnapshotCompleted(uint256 indexed snapshotId, uint256 totalAddresses);
event SnapshotFinalized(uint256 indexed snapshotId);
```

## Security Considerations

### Pause Protection

- Contract is automatically paused during snapshot processing
- Prevents token transfers that could corrupt snapshot data
- Automatic unpause when processing completes

### Access Control

- Only contract owner can create and manage snapshots
- All query functions are publicly accessible
- Emergency functions require owner privileges

### Data Integrity

- Batch processing ensures all balances are captured accurately
- Pause mechanism prevents race conditions
- Direct storage access eliminates binary search complexity

### Gas Limits

- Configurable batch sizes prevent gas limit failures
- Default batch size can be adjusted based on network conditions
- Emergency reset available for recovery

## Error Messages

| Error                                | Cause                                     |
| ------------------------------------ | ----------------------------------------- |
| `"Invalid snapshot ID"`              | Snapshot ID is 0 or doesn't exist         |
| `"Snapshot already completed"`       | Trying to process completed snapshot      |
| `"Snapshot not completed yet"`       | Querying incomplete snapshot              |
| `"Snapshot not in processing state"` | Trying to process non-processing snapshot |
| `"Invalid batch size"`               | Batch size is 0 or > 200                  |
| `"Snapshot already finalized"`       | Trying to modify finalized snapshot       |
| `"Cannot reset completed snapshot"`  | Trying to reset completed snapshot        |

## Best Practices

### 1. **Batch Size Configuration**

```solidity
// Start with default, adjust based on gas usage
lockToken.setDefaultBatchSize(100);  // For normal networks
lockToken.setDefaultBatchSize(50);   // For congested networks
lockToken.setDefaultBatchSize(200);  // For fast/cheap networks
```

### 2. **Processing Monitoring**

```solidity
// Always check completion before using snapshot
uint256 snapshotId = lockToken.createSnapshot();

// Monitor progress
while (!lockToken.isSnapshotCompleted(snapshotId)) {
    (,, uint256 progress,,) = lockToken.getSnapshotStatus(snapshotId);
    console.log("Processing:", progress, "%");

    // Continue processing
    lockToken.continueSnapshot(snapshotId);

    // Add delay to prevent spam
    // (in practice, this would be separate transactions)
}
```

### 3. **Emergency Handling**

```solidity
// Always have emergency procedures
try lockToken.continueSnapshot(snapshotId) {
    // Success
} catch {
    // Emergency reset if needed
    lockToken.resetSnapshotProcessing(snapshotId);
}
```

### 4. **Governance Integration**

```solidity
// Create snapshots well before voting
function scheduleVote() external {
    uint256 snapshotId = createSnapshot();

    // Allow time for processing
    votingStartTime = block.timestamp + 1 days;
    governanceSnapshotId = snapshotId;
}
```

## Migration from Legacy Systems

### Compatibility Features

- **Storage Layout**: Maintains exact compatibility with original snapshot variables
- **Function Signatures**: Core query functions unchanged
- **Event Names**: Maintains compatibility with existing event listeners

### Upgrade Path

1. **Deploy New Contract**: UUPS upgrade maintains state
2. **Verify Compatibility**: All existing snapshots remain accessible
3. **New Features**: Batch processing available for new snapshots
4. **Legacy Support**: Old snapshots continue to work normally

## Next Steps

- [Lock Management API](lock-management.md) - Token locking system
- [Events Documentation](events.md) - Complete event reference
- [Integration Guide](../guides/integration.md) - Implementation examples
