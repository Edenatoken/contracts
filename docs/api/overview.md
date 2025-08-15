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

| Function                | Access   | Description                                 |
| ----------------------- | -------- | ------------------------------------------- |
| `lock()`                | Approved | Lock tokens for a specific address          |
| `transferWithLock()`    | Approved | Transfer and lock tokens in one transaction |
| `claim()`               | Public   | Release own expired locks                   |
| `manualUnlock()`        | Approved | Release locks for any address               |
| `getLockedBalance()`    | View     | Get locked token amount                     |
| `getAvailableBalance()` | View     | Get transferable balance                    |

[Detailed Lock Management API](lock-management.md)

### Snapshot System

Functions for creating and querying historical balance snapshots.

| Function                 | Access | Description                      |
| ------------------------ | ------ | -------------------------------- |
| `snapshot()`             | Owner  | Create balance snapshot          |
| `balanceOfAt()`          | View   | Get balance at specific snapshot |
| `getSnapshotAddresses()` | View   | Get addresses in snapshot        |
| `addAddressToSnapshot()` | Owner  | Add address to existing snapshot |

[Detailed Snapshot API](snapshot.md)

### Account Management

Functions for managing addresses and account permissions.

| Function            | Access | Description                   |
| ------------------- | ------ | ----------------------------- |
| `registerAddress()` | Owner  | Register address for tracking |
| `freezeAccount()`   | Owner  | Freeze account transactions   |
| `addApproveArr()`   | Owner  | Add approved address          |
| `isApproved()`      | View   | Check if address is approved  |

[Detailed Account Management API](account.md)

### Configuration

Functions for contract configuration and control.

| Function                 | Access | Description                |
| ------------------------ | ------ | -------------------------- |
| `setLockupDays()`        | Owner  | Set default lock period    |
| `setAutoUnlockEnabled()` | Owner  | Enable/disable auto unlock |
| `pause()`                | Owner  | Pause contract operations  |
| `unpause()`              | Owner  | Resume contract operations |

## Access Control

The contract implements a multi-tier access control system:

### Access Levels

| Level        | Description             | Functions                                        |
| ------------ | ----------------------- | ------------------------------------------------ |
| **Public**   | Anyone can call         | `transfer()`, `claim()`, view functions          |
| **Approved** | Approved addresses only | `lock()`, `transferWithLock()`, `manualUnlock()` |
| **Owner**    | Contract owner only     | Configuration, admin functions                   |

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

| Operation          | Typical Gas Cost | Optimized Cost | Savings |
| ------------------ | ---------------- | -------------- | ------- |
| Lock Balance Query | ~50,000 gas      | ~5,000 gas     | 90%     |
| Multi-unlock       | ~200,000 gas     | ~80,000 gas    | 60%     |
| Snapshot Creation  | Variable         | Optimized      | 30-50%  |

## Events

The contract emits comprehensive events for all major operations:

```solidity
event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);
event Unlock(address indexed holder, uint256 value, address indexed operator);
event Freeze(address indexed holder);
event Unfreeze(address indexed holder);
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
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

// Create snapshot for governance
uint256 snapshotId = lockToken.snapshot();
uint256 balanceAtSnapshot = lockToken.balanceOfAt(voter, snapshotId);
```

## Next Steps

- [Lock Management API](lock-management.md) - Detailed lock functions
- [Snapshot API](snapshot.md) - Historical balance tracking
- [Integration Guide](../guides/integration.md) - Step-by-step integration
