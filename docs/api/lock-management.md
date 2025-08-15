# Lock Management API

The lock management system is the core feature of EDENA Token V2, allowing tokens to be locked for specific time periods with automated release mechanisms.

## Core Concepts

### Lock Structure

Each lock is defined by the `LockInfo` struct:

```solidity
struct LockInfo {
    uint256 _releaseTime;  // Unix timestamp for unlock
    uint256 _amount;       // Amount of tokens locked
}
```

### Lock Storage

- `timelockList[address]`: Array of locks per address
- `lockedAmount[address]`: Total locked amount (gas optimized)

## Lock Creation Functions

### `lock()`

Locks tokens that the holder already possesses.

```solidity
function lock(
    address holder,
    uint256 value,
    uint256 releaseTime
) public onlyApproved nonReentrant returns (bool)
```

**Parameters:**

- `holder`: Address whose tokens will be locked
- `value`: Amount of tokens to lock (in wei)
- `releaseTime`: Unix timestamp when tokens can be unlocked

**Requirements:**

- Caller must be approved or owner
- `holder` cannot be zero address
- `value` must be greater than 0
- `releaseTime` must be in the future
- Holder must have sufficient unlocked balance

**Example:**

```solidity
// Lock 1000 tokens for 90 days
uint256 amount = 1000 * 10**18;
uint256 releaseTime = block.timestamp + (90 * 24 * 60 * 60);
lockToken.lock(userAddress, amount, releaseTime);
```

### `transferWithLock()`

Transfers tokens from sender to recipient and immediately locks them.

```solidity
function transferWithLock(
    address holder,
    uint256 value,
    uint256 releaseTime
) public onlyApproved nonReentrant returns (bool)
```

**Parameters:**

- `holder`: Recipient address
- `value`: Amount to transfer and lock
- `releaseTime`: When tokens can be unlocked

**Features:**

- Auto-registers recipient if not already registered
- Atomic transfer + lock operation
- Prevents double-spending attacks

**Example:**

```solidity
// Transfer 500 tokens and lock for 6 months
uint256 amount = 500 * 10**18;
uint256 sixMonths = block.timestamp + (180 * 24 * 60 * 60);
lockToken.transferWithLock(recipient, amount, sixMonths);
```

### `transferWithLockEasy()`

Simplified version using ETH units and day counts.

```solidity
function transferWithLockEasy(
    address holder,
    uint256 valueEth,
    uint256 lockupDaysParam
) public onlyApproved returns (bool)
```

**Parameters:**

- `holder`: Recipient address
- `valueEth`: Amount in ETH units (will be converted to wei)
- `lockupDaysParam`: Lock duration in days

**Example:**

```solidity
// Transfer 100 ETH worth of tokens, lock for 30 days
lockToken.transferWithLockEasy(recipient, 100, 30);
```

### `transferWithLockBase()`

Uses the contract's default lock period.

```solidity
function transferWithLockBase(
    address holder,
    uint256 value
) public onlyApproved returns (bool)
```

**Example:**

```solidity
// Lock with default period (90 days)
lockToken.transferWithLockBase(recipient, 1000 * 10**18);
```

## Lock Release Functions

### `claim()`

Allows users to release their own expired locks.

```solidity
function claim() public nonReentrant returns (uint256)
```

**Returns:** Number of locks that were successfully released

**Features:**

- Automatic detection of expired locks
- Releases all expired locks in single transaction
- Gas-efficient batch processing

**Example:**

```solidity
uint256 releasedLocks = lockToken.claim();
console.log("Released", releasedLocks, "expired locks");
```

### `manualUnlock()`

Allows approved addresses to release locks for any user.

```solidity
function manualUnlock(address holder) public onlyApproved nonReentrant returns (uint256)
```

**Parameters:**

- `holder`: Address whose locks to release

**Use Cases:**

- Emergency unlock by governance
- Automated unlock by management contracts
- Batch unlock operations

**Example:**

```solidity
// Governance unlocks user's expired locks
uint256 released = lockToken.manualUnlock(userAddress);
```

### `unlock()`

Releases a specific lock by index.

```solidity
function unlock(address holder, uint256 idx) public onlyApproved nonReentrant returns (bool)
```

**Parameters:**

- `holder`: Address whose lock to release
- `idx`: Index of the lock to release

**Requirements:**

- Lock must be expired (current time >= release time)
- Index must be valid

## Lock Query Functions

### `getLockedBalance()`

Returns total locked amount for an address.

```solidity
function getLockedBalance(address owner) public view returns (uint256)
```

**Gas Optimized:** Uses `lockedAmount` mapping for O(1) lookup.

### `getAvailableBalance()`

Returns transferable balance (total - locked).

```solidity
function getAvailableBalance(address owner) public view returns (uint256)
```

**Example:**

```solidity
uint256 total = lockToken.balanceOf(user);
uint256 locked = lockToken.getLockedBalance(user);
uint256 available = lockToken.getAvailableBalance(user);
// total = locked + available
```

### `getLockCount()`

Returns number of active locks for an address.

```solidity
function getLockCount(address holder) public view returns (uint256)
```

### `getLockDetails()`

Returns comprehensive lock information for an address.

```solidity
function getLockDetails(address holder) public view returns (
    uint256 lockCount,
    uint256 totalLockedAmount,
    uint256[] memory releaseTimes,
    uint256[] memory amounts
)
```

**Returns:**

- `lockCount`: Number of active locks
- `totalLockedAmount`: Total locked tokens
- `releaseTimes`: Array of unlock timestamps
- `amounts`: Array of locked amounts

**Example:**

```solidity
(
    uint256 count,
    uint256 total,
    uint256[] memory times,
    uint256[] memory amounts
) = lockToken.getLockDetails(userAddress);

for (uint i = 0; i < count; i++) {
    console.log("Lock", i, ":", amounts[i], "tokens until", times[i]);
}
```

## Aggregate Query Functions

### `getLockSummary()`

Returns overall lock statistics across all addresses.

```solidity
function getLockSummary() public view returns (
    uint256 totalLockedAddresses,
    uint256 totalLockedAmount,
    uint256 totalLockCount
)
```

**Use Cases:**

- Dashboard statistics
- Governance metrics
- Market analysis

### `getAllLockedBalances()`

Returns detailed information for all addresses with locks.

```solidity
function getAllLockedBalances() public view returns (
    address[] memory holders,
    uint256[] memory lockedAmounts,
    uint256[] memory lockCounts
)
```

**Returns parallel arrays:**

- `holders`: Addresses with locked tokens
- `lockedAmounts`: Locked amount per address
- `lockCounts`: Number of locks per address

## Auto Unlock Feature

### Configuration

```solidity
bool public autoUnlockEnabled;

function setAutoUnlockEnabled(bool _enabled) public onlyOwner
```

### Behavior

When enabled, `transfer()` and `transferFrom()` automatically release expired locks:

```solidity
function transfer(address to, uint256 value) public override {
    if (autoUnlockEnabled && timelockList[msg.sender].length > 0) {
        _autoUnlock(msg.sender);
    }
    // ... rest of transfer logic
}
```

## Gas Optimization

### Efficient Lock Removal

The contract uses an optimized removal algorithm:

```solidity
function _removeLock(address holder, uint256 idx) internal {
    // Move last element to current position
    uint256 lastIndex = timelockList[holder].length - 1;
    if (idx != lastIndex) {
        timelockList[holder][idx] = timelockList[holder][lastIndex];
    }
    timelockList[holder].pop();

    // Update cached amount
    lockedAmount[holder] -= amount;
}
```

**Benefits:**

- O(1) removal instead of O(n)
- No array gaps
- Maintains cache consistency

### Batch Operations

Multiple expired locks are processed in a single transaction:

```solidity
function _autoUnlock(address holder) internal returns (uint256) {
    uint256 unlockedCount = 0;
    uint256 i = 0;

    while (i < timelockList[holder].length) {
        if (block.timestamp >= timelockList[holder][i]._releaseTime) {
            _removeLock(holder, i);
            unlockedCount++;
            // Don't increment i since array shrunk
        } else {
            i++;
        }
    }

    return unlockedCount;
}
```

## Events

```solidity
event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);
event Unlock(address indexed holder, uint256 value, address indexed operator);
```

**Event Parameters:**

- `holder`: Address whose tokens are locked/unlocked
- `value`: Amount of tokens
- `releaseTime`: When tokens can be unlocked (Lock event only)
- `operator`: Address that initiated the operation

## Security Considerations

### Transfer Restrictions

The `_beforeTokenTransfer` hook prevents transfer of locked tokens:

```solidity
function _beforeTokenTransfer(address from, address to, uint256 amount) internal override {
    if (from != address(0)) {
        require(
            balanceOf(from) - lockedAmount[from] >= amount,
            "Transfer amount exceeds unlocked balance"
        );
    }
}
```

### Reentrancy Protection

All state-changing functions use `nonReentrant` modifier to prevent reentrancy attacks.

### Access Control

Lock creation functions require `onlyApproved` permission to prevent unauthorized locking.

## Error Messages

| Error                                      | Cause                                |
| ------------------------------------------ | ------------------------------------ |
| `"Cannot lock zero address"`               | Attempting to lock for address(0)    |
| `"Lock amount must be greater than 0"`     | Zero or negative lock amount         |
| `"Release time must be in the future"`     | Invalid timestamp                    |
| `"Insufficient unlocked balance for lock"` | Not enough transferable tokens       |
| `"Lock period not expired"`                | Trying to unlock before release time |
| `"Lock index does not exist"`              | Invalid lock index                   |

## Next Steps

- [Snapshot API](snapshot.md) - Historical balance tracking
- [Account Management](account.md) - User and permission management
