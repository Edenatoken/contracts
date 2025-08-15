# Events Documentation

EDENA Token V2 emits comprehensive events for all major operations, enabling efficient monitoring, analytics, and integration with external systems.

## Event Categories

### Lock Management Events

Events related to token locking and unlocking operations.

### Account Management Events

Events for account state changes and permissions.

### Snapshot Events

Events for snapshot creation and management.

### System Events

Events for contract administration and configuration.

## Lock Management Events

### `Lock` Event

Emitted when tokens are locked for an address.

```solidity
event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);
```

**Parameters:**

- `holder` (indexed): Address whose tokens are being locked
- `value`: Amount of tokens locked (in wei)
- `releaseTime`: Unix timestamp when tokens can be unlocked
- `operator` (indexed): Address that initiated the lock operation

**Triggered by:**

- `lock()` - Direct lock creation
- `transferWithLock()` - Transfer with immediate lock
- `transferWithLockEasy()` - Easy lock creation
- `transferWithLockBase()` - Default period lock

**Example Usage:**

```solidity
// Listen for lock events
contract LockMonitor {
    event LockCreated(address indexed user, uint256 amount, uint256 duration);

    function onLockEvent(address holder, uint256 value, uint256 releaseTime, address operator) external {
        uint256 duration = releaseTime - block.timestamp;
        emit LockCreated(holder, value, duration);

        // Store lock data for analytics
        lockDatabase[holder].push(LockData(value, releaseTime, operator));
    }
}
```

### `Unlock` Event

Emitted when locked tokens are released.

```solidity
event Unlock(address indexed holder, uint256 value, address indexed operator);
```

**Parameters:**

- `holder` (indexed): Address whose tokens are being unlocked
- `value`: Amount of tokens unlocked (in wei)
- `operator` (indexed): Address that initiated the unlock operation

**Triggered by:**

- `claim()` - User claims expired locks
- `manualUnlock()` - Approved address unlocks
- `unlock()` - Specific lock unlock
- `_autoUnlock()` - Automatic unlock during transfers

**Example Usage:**

```solidity
// Track unlock patterns
contract UnlockAnalytics {
    mapping(address => uint256) public totalUnlocked;
    mapping(address => uint256) public unlockCount;

    function trackUnlock(address holder, uint256 value, address operator) external {
        totalUnlocked[holder] += value;
        unlockCount[holder]++;

        // Notify user
        notificationService.sendUnlockNotification(holder, value);
    }
}
```

## Account Management Events

### `Freeze` Event

Emitted when an account is frozen.

```solidity
event Freeze(address indexed holder);
```

**Parameters:**

- `holder` (indexed): Address that was frozen

**Triggered by:**

- `freezeAccount()` - Manual account freeze

**Effects:**

- Account cannot transfer tokens
- Account cannot claim locks
- Account blocked from all token operations

**Example Usage:**

```solidity
// Compliance monitoring
contract ComplianceTracker {
    mapping(address => uint256) public freezeTimestamp;

    function onAccountFreeze(address holder) external {
        freezeTimestamp[holder] = block.timestamp;

        // Log compliance action
        complianceLog.recordFreeze(holder, "Account frozen by admin");

        // Notify relevant parties
        notifyRegulators(holder, "ACCOUNT_FROZEN");
    }
}
```

### `Unfreeze` Event

Emitted when a frozen account is unfrozen.

```solidity
event Unfreeze(address indexed holder);
```

**Parameters:**

- `holder` (indexed): Address that was unfrozen

**Triggered by:**

- `unfreezeAccount()` - Manual account unfreeze

**Example Usage:**

```solidity
// Track freeze duration
contract FreezeAnalytics {
    function onAccountUnfreeze(address holder) external {
        uint256 freezeDuration = block.timestamp - freezeTimestamp[holder];

        // Record statistics
        freezeStats[holder].totalFreezeTime += freezeDuration;
        freezeStats[holder].freezeCount++;

        // Clear freeze timestamp
        delete freezeTimestamp[holder];
    }
}
```

## Snapshot Events

### `SnapshotCreated` Event

Emitted when a new snapshot is created.

```solidity
event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
```

**Parameters:**

- `snapshotId` (indexed): Unique identifier for the snapshot
- `totalAddresses`: Number of addresses included in the snapshot
- `totalSupply`: Total token supply at snapshot time

**Triggered by:**

- `snapshot()` - Manual snapshot creation

**Example Usage:**

```solidity
// Governance snapshot tracking
contract GovernanceManager {
    mapping(uint256 => ProposalData) public proposals;

    function onSnapshotCreated(uint256 snapshotId, uint256 totalAddresses, uint256 totalSupply) external {
        // Create governance proposal with this snapshot
        proposals[currentProposalId] = ProposalData({
            snapshotId: snapshotId,
            eligibleVoters: totalAddresses,
            totalVotingPower: totalSupply,
            created: block.timestamp
        });

        // Notify governance participants
        notifyGovernanceParticipants(snapshotId);
    }
}
```

## System Events (Inherited)

### ERC20 Standard Events

#### `Transfer` Event

```solidity
event Transfer(address indexed from, address indexed to, uint256 value);
```

**Enhanced Behavior:**

- Includes automatic address registration
- Triggers auto-unlock when enabled
- Validates against locked balances

#### `Approval` Event

```solidity
event Approval(address indexed owner, address indexed spender, uint256 value);
```

### Pausable Events

#### `Paused` Event

```solidity
event Paused(address account);
```

**Triggered by:**

- `pause()` - Emergency pause activation

#### `Unpaused` Event

```solidity
event Unpaused(address account);
```

**Triggered by:**

- `unpause()` - Emergency pause deactivation

### Ownership Events

#### `OwnershipTransferred` Event

```solidity
event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
```

**Critical for:**

- Security monitoring
- Administrative transitions
- Audit trails

## Event Filtering and Monitoring

### Filtering by Address

```javascript
// Filter lock events for specific address
const lockEvents = await lockToken.queryFilter(
  lockToken.filters.Lock(userAddress, null, null, null)
);

// Filter by operator
const operatorLocks = await lockToken.queryFilter(
  lockToken.filters.Lock(null, null, null, operatorAddress)
);
```

### Time Range Filtering

```javascript
// Get events from specific block range
const fromBlock = 1000000;
const toBlock = 2000000;

const lockEvents = await lockToken.queryFilter(
  lockToken.filters.Lock(),
  fromBlock,
  toBlock
);
```

### Real-time Monitoring

```javascript
// Listen for new lock events
lockToken.on("Lock", (holder, value, releaseTime, operator, event) => {
  console.log(
    `New lock: ${holder} locked ${value} tokens until ${releaseTime}`
  );

  // Update UI or database
  updateLockDisplay(holder, value, releaseTime);
});

// Listen for unlock events
lockToken.on("Unlock", (holder, value, operator, event) => {
  console.log(`Unlock: ${holder} unlocked ${value} tokens`);

  // Update analytics
  recordUnlockEvent(holder, value, operator);
});
```

## Event-Driven Architecture Examples

### Lock Analytics Service

```solidity
contract LockAnalytics {
    struct LockStats {
        uint256 totalLocked;
        uint256 totalUnlocked;
        uint256 lockCount;
        uint256 unlockCount;
        uint256 averageLockDuration;
    }

    mapping(address => LockStats) public userStats;
    mapping(uint256 => uint256) public dailyLockVolume;

    function onLock(address holder, uint256 value, uint256 releaseTime, address operator) external {
        LockStats storage stats = userStats[holder];
        stats.totalLocked += value;
        stats.lockCount++;

        // Update daily statistics
        uint256 day = block.timestamp / 86400;
        dailyLockVolume[day] += value;

        // Calculate average lock duration
        uint256 duration = releaseTime - block.timestamp;
        stats.averageLockDuration = (stats.averageLockDuration * (stats.lockCount - 1) + duration) / stats.lockCount;
    }

    function onUnlock(address holder, uint256 value, address operator) external {
        LockStats storage stats = userStats[holder];
        stats.totalUnlocked += value;
        stats.unlockCount++;
    }
}
```

### Notification Service

```solidity
contract NotificationService {
    event LockNotification(address indexed user, string message, uint256 timestamp);
    event UnlockNotification(address indexed user, string message, uint256 timestamp);

    function onLockCreated(address holder, uint256 value, uint256 releaseTime, address operator) external {
        string memory message = string(abi.encodePacked(
            "Locked ", Strings.toString(value / 10**18), " tokens until ",
            Strings.toString(releaseTime)
        ));

        emit LockNotification(holder, message, block.timestamp);
    }

    function onTokensUnlocked(address holder, uint256 value, address operator) external {
        string memory message = string(abi.encodePacked(
            "Unlocked ", Strings.toString(value / 10**18), " tokens"
        ));

        emit UnlockNotification(holder, message, block.timestamp);
    }
}
```

### Governance Integration

```solidity
contract GovernanceEvents {
    event ProposalSnapshotCreated(uint256 indexed proposalId, uint256 indexed snapshotId);
    event VotingPowerCalculated(address indexed voter, uint256 power, uint256 indexed proposalId);

    function createProposalSnapshot(uint256 proposalId) external {
        uint256 snapshotId = lockToken.snapshot();
        emit ProposalSnapshotCreated(proposalId, snapshotId);
    }

    function calculateVotingPower(address voter, uint256 proposalId) external view returns (uint256) {
        uint256 snapshotId = getProposalSnapshot(proposalId);
        uint256 power = lockToken.balanceOfAt(voter, snapshotId);

        emit VotingPowerCalculated(voter, power, proposalId);
        return power;
    }
}
```

## Event Best Practices

### 1. **Efficient Indexing**

Use indexed parameters for frequently queried fields:

```solidity
// Good: Indexed for efficient filtering
event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);

// Less efficient: No indexing
event Lock(address holder, uint256 value, uint256 releaseTime, address operator);
```

### 2. **Event Data Structure**

Include sufficient context in events:

```solidity
// Good: Comprehensive data
event LockCreated(
    address indexed holder,
    uint256 value,
    uint256 releaseTime,
    address indexed operator,
    uint256 lockId,
    string lockType
);

// Minimal: Basic data only
event LockCreated(address holder, uint256 value);
```

### 3. **Event Monitoring**

Set up proper event monitoring infrastructure:

```javascript
// Comprehensive event listener
async function setupEventMonitoring() {
  // Historical events
  const pastEvents = await token.queryFilter(token.filters.Lock(), 0, "latest");

  // Real-time monitoring
  token.on("Lock", handleLockEvent);
  token.on("Unlock", handleUnlockEvent);
  token.on("SnapshotCreated", handleSnapshotEvent);

  // Error handling
  token.on("error", (error) => {
    console.error("Token event error:", error);
    // Implement retry logic
  });
}
```

## Integration with External Systems

### Database Integration

```javascript
// Event to database mapping
async function processLockEvent(holder, value, releaseTime, operator) {
  await database.locks.insert({
    holder: holder,
    value: value.toString(),
    releaseTime: new Date(releaseTime * 1000),
    operator: operator,
    status: "active",
    createdAt: new Date(),
  });
}
```

### Analytics Platform

```javascript
// Send events to analytics
function sendToAnalytics(eventName, data) {
  analytics.track(eventName, {
    ...data,
    timestamp: Date.now(),
    network: "polygon",
    contract: lockToken.address,
  });
}

// Track lock events
lockToken.on("Lock", (holder, value, releaseTime, operator) => {
  sendToAnalytics("token_locked", {
    holder,
    value: value.toString(),
    duration: releaseTime - Math.floor(Date.now() / 1000),
    operator,
  });
});
```

## Next Steps

- [Integration Guide](../guides/integration.md) - How to integrate event monitoring
- [Lock Management API](lock-management.md) - Detailed lock operations
