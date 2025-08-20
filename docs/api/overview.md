# API Overview

The EDENA Token V2 smart contract provides a comprehensive API for managing locked tokens, snapshots, and account permissions. This page provides an overview of all available functions organized by category.

## Contract Interface

The main contract `LockToken` inherits from multiple OpenZeppelin contracts and implements the custom `Approvable` system.

```solidity
contract LockToken is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    Approvable
```

## API Categories

### Lock Management

Functions for creating, releasing, and querying token locks.

| Function                 | Access   | Description                                 |
| ------------------------ | -------- | ------------------------------------------- |
| `transferWithLock()`     | Approved | Transfer and lock tokens in one transaction |
| `transferWithLockEasy()` | Approved | Easy lock with ETH units and days           |
| `transferWithLockBase()` | Approved | Lock with default period                    |
| `claim()`                | Public   | Release own expired locks                   |
| `manualUnlock()`         | Approved | Release locks for any address               |
| `unlock()`               | Approved | Release specific lock by index              |
| `getLockedBalance()`     | View     | Get locked token amount                     |
| `getAvailableBalance()`  | View     | Get transferable balance                    |
| `getLockDetails()`       | View     | Get detailed lock information               |

[Detailed Lock Management API](lock-management.md)

### Snapshot System

Batch processing system for creating and querying historical balance snapshots with gas optimization.

| Function                    | Access | Description                           |
| --------------------------- | ------ | ------------------------------------- |
| `createSnapshot()`          | Owner  | Create batch snapshot with auto-start |
| `processSnapshot()`         | Owner  | Process snapshot in batches           |
| `continueSnapshot()`        | Owner  | Continue processing with default size |
| `finalizeSnapshot()`        | Owner  | Finalize completed snapshot           |
| `resetSnapshotProcessing()` | Owner  | Reset snapshot processing state       |
| `balanceOfAt()`             | View   | Get balance at specific snapshot      |
| `getSnapshotTotalSupply()`  | View   | Get total supply at snapshot          |
| `getSnapshotTimestamp()`    | View   | Get snapshot creation time            |
| `getAllSnapshotIds()`       | View   | Get all snapshot IDs                  |
| `getAccountSnapshotIds()`   | View   | Get account's snapshot IDs            |
| `getSnapshotStatus()`       | View   | Get snapshot processing status        |
| `getSnapshotProgress()`     | View   | Get snapshot progress information     |
| `isSnapshotCompleted()`     | View   | Check if snapshot is completed        |

[Detailed Snapshot API](snapshot.md)

### Account Management

Functions for managing addresses and account permissions.

| Function                      | Access | Description                       |
| ----------------------------- | ------ | --------------------------------- |
| `registerAddress()`           | Owner  | Register address for tracking     |
| `unregisterAddress()`         | Owner  | Remove address from registry      |
| `getRegisteredAddresses()`    | View   | Get all registered addresses      |
| `getRegisteredAddressCount()` | View   | Get count of registered addresses |
| `freezeAccount()`             | Owner  | Freeze account transactions       |
| `unfreezeAccount()`           | Owner  | Unfreeze account transactions     |
| `addApproveArr()`             | Owner  | Add approved address              |
| `removeApproveArr()`          | Owner  | Remove approved address           |
| `isApproved()`                | View   | Check if address is approved      |
| `getApprovedList()`           | View   | Get all approved addresses        |

[Detailed Account Management API](account.md)

### Configuration

Functions for contract configuration and control.

| Function                  | Access | Description                     |
| ------------------------- | ------ | ------------------------------- |
| `setLockupDays()`         | Owner  | Set default lock period         |
| `setAutoUnlockEnabled()`  | Owner  | Enable/disable auto unlock      |
| `setLockCooldownPeriod()` | Owner  | Set cooldown between locks      |
| `setDefaultBatchSize()`   | Owner  | Set default snapshot batch size |
| `pause()`                 | Owner  | Pause contract operations       |
| `unpause()`               | Owner  | Resume contract operations      |
| `burn()`                  | Public | Burn own unlocked tokens        |

## Access Control

The contract implements a multi-tier access control system:

### Access Levels

| Level        | Description             | Functions                                                     |
| ------------ | ----------------------- | ------------------------------------------------------------- |
| **Public**   | Anyone can call         | `transfer()`, `claim()`, `burn()`, view functions             |
| **Approved** | Approved addresses only | `transferWithLock()`, `manualUnlock()`, `unlock()`            |
| **Owner**    | Contract owner only     | Configuration, admin functions, snapshots, account management |

### Modifiers

```solidity
modifier onlyOwner()        // Owner only
modifier onlyApproved()     // Approved addresses + Owner
modifier whenNotPaused()    // When contract is not paused
modifier notFrozen(address) // When address is not frozen
modifier nonReentrant()     // Reentrancy protection
```

## Error Handling

All functions implement comprehensive error checking with descriptive error messages:

```solidity
// Example error messages
"Cannot lock zero address"
"Lock amount must be greater than 0"
"Insufficient unlocked balance for lock"
"Transfer amount exceeds unlocked balance"
"Must call by Owner or Approved Contract"
```

## Gas Optimization Features

### Efficient Data Structures

- **O(1) Lock Balance**: `lockedAmount` mapping for instant balance queries
- **Optimized Arrays**: Efficient element removal without gaps
- **Batch Operations**: Multiple operations in single transaction

### Gas Cost Examples

| Operation              | Traditional Cost   | Optimized Cost  | Savings |
| ---------------------- | ------------------ | --------------- | ------- |
| Lock Balance Query     | ~50,000 gas        | ~5,000 gas      | 90%     |
| Multi-unlock           | ~200,000 gas       | ~80,000 gas     | 60%     |
| Snapshot Creation      | Out of Gas (DoS)   | Batch Process   | 100%    |
| Snapshot Balance Query | ~30,000 gas        | ~5,000 gas      | 83%     |
| Large Snapshot (1000+) | Failed (Gas Limit) | ~200K per batch | Success |

## Events

The contract emits comprehensive events for all major operations:

```solidity
// Lock/Unlock Events
event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);
event Unlock(address indexed holder, uint256 value, address indexed operator);

// Account Management Events
event Freeze(address indexed holder);
event Unfreeze(address indexed holder);
event ApproveAdded(address indexed approver, address indexed newApproved);
event ApproveRemoved(address indexed approver, address indexed removedApproved);
event AddressRegistered(address indexed registrar, address indexed newAddress);
event AddressUnregistered(address indexed registrar, address indexed removedAddress);

// System Events
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
event SnapshotCompleted(uint256 indexed snapshotId, uint256 totalAddresses);
event SnapshotProcessingStarted(uint256 indexed snapshotId);
event SnapshotProcessingResumed(uint256 indexed snapshotId);
event SnapshotFinalized(uint256 indexed snapshotId);
event LockupDaysChanged(address indexed owner, uint256 oldDays, uint256 newDays);
event AutoUnlockEnabledChanged(address indexed owner, bool enabled);
event LockCooldownChanged(address indexed owner, uint256 oldCooldown, uint256 newCooldown);
```

[Complete Events Reference](events.md)

## Integration Examples

### Basic Integration

```solidity
// Check if address has locked tokens
uint256 locked = lockToken.getLockedBalance(userAddress);
uint256 available = lockToken.getAvailableBalance(userAddress);

// Transfer with lock (requires approval)
lockToken.transferWithLock(recipient, amount, releaseTime);

// User claims expired locks
uint256 unlockedCount = lockToken.claim();
```

### Advanced Usage

```solidity
// Get detailed lock information
(
    uint256 lockCount,
    uint256 totalLocked,
    uint256[] memory releaseTimes,
    uint256[] memory amounts
) = lockToken.getLockDetails(userAddress);

// Create batch snapshot for governance
uint256 snapshotId = lockToken.createSnapshot();

// Continue processing if needed
bool completed = lockToken.isSnapshotCompleted(snapshotId);
if (!completed) {
    lockToken.continueSnapshot(snapshotId);
}

// Query balance after completion
uint256 balanceAtSnapshot = lockToken.balanceOfAt(voter, snapshotId);
```

## Next Steps

- [Lock Management API](lock-management.md) - Detailed lock functions
- [Snapshot API](snapshot.md) - Historical balance tracking
- [Integration Guide](../guides/integration.md) - Step-by-step integration
