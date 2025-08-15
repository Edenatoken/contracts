# EDENA Token V2 - Advanced Lock Token with UUPS Upgradeability

![Solidity](https://img.shields.io/badge/Solidity-0.8.22-blue.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)
![OpenZeppelin](https://img.shields.io/badge/OpenZeppelin-5.0-orange.svg)
![Polygon](https://img.shields.io/badge/Polygon-Ready-purple.svg)
![UUPS](https://img.shields.io/badge/UUPS-Upgradeable-brightgreen.svg)

**EDENA Token V2** is a next-generation ERC20 token that implements advanced lock-up systems and UUPS (Universal Upgradeable Proxy Standard) upgrade patterns. It provides efficient gas usage, comprehensive governance features, and future extensibility.

## Project Overview

EDENA V2 is an advanced smart contract designed to overcome the limitations of existing lock-up tokens and to integrate with exchange listings and DeFi ecosystems.

### Core Features

- UUPS Upgrade Pattern: Future feature expansion and security improvements possible
- Gas-optimized Lock System: O(1) lookup with `lockedAmount` mapping
- Comprehensive Access Control: Granular access control with Approvable system
- Real-time Lock Monitoring: Real-time querying of overall lock status
- Enterprise-Ready Security: Reentrancy attack prevention, pause functionality

## Token Specifications

| Item             | Value            |
| ---------------- | ---------------- |
| Contract Name    | LockToken        |
| Solidity Version | 0.8.22           |
| Standard         | ERC20Upgradeable |
| Decimals         | 18               |
| Upgrade Pattern  | UUPS             |
| Network          | Polygon          |
| License          | MIT              |

## Architecture

### Contract Structure

```
LockToken (Main Contract)
├── Initializable
├── ERC20Upgradeable
├── PausableUpgradeable
├── OwnableUpgradeable
├── UUPSUpgradeable
├── ReentrancyGuardUpgradeable
└── Approvable (Custom)
```

### Core Components

#### 1. Approvable System

```solidity
contract Approvable {
    address[] approveArr;
    modifier onlyApproved();
    function addApproveArr(address);
    function removeApproveArr(address);
    function isApproved(address) returns (bool);
}
```

#### 2. Lock System

```solidity
struct LockInfo {
    uint256 _releaseTime;  // Unlock time (Unix timestamp)
    uint256 _amount;       // Locked token amount
}

mapping(address => LockInfo[]) public timelockList;
mapping(address => uint256) public lockedAmount;  // Gas optimization
```

#### 3. Snapshot System

```solidity
mapping(uint256 => uint256) public snapshotTotalSupply;
mapping(uint256 => mapping(address => uint256)) public snapshotBalances;
mapping(uint256 => address[]) public snapshotAddresses;
```

## Main Features

### 1. Advanced Lock Management

#### Lock Creation

- `lock()`: Direct lock setup
- `transferWithLock()`: Transfer with simultaneous lock
- `transferWithLockEasy()`: Simple day-based lock
- `transferWithLockBase()`: Lock with default settings

#### Lock Release

- `claim()`: User directly releases expired locks
- `manualUnlock()`: Approved address manually releases
- `unlock()`: Release specific index lock

#### Lock Queries

- `getLockSummary()`: Query overall lock statistics
- `getAllLockedBalances()`: Detailed information of all locked addresses
- `getLockDetails()`: Detailed lock information for specific address
- `getAvailableBalance()`: Transferable balance

### 2. Optimized Token Transfer

#### Auto Unlock System

```solidity
function transfer(address to, uint256 value) public override {
    if (autoUnlockEnabled && timelockList[msg.sender].length > 0) {
        _autoUnlock(msg.sender);
    }
    _registerAddressIfNeeded(to);
    return super.transfer(to, value);
}
```

#### Transfer Restriction Validation

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

### 3. Snapshot and Governance

#### Snapshot Creation

- `snapshot()`: Create snapshot of all address balances
- `addAddressToSnapshot()`: Add specific address to snapshot
- `addAddressesToSnapshot()`: Batch add multiple addresses

#### Snapshot Queries

- `balanceOfAt()`: Query balance at specific time point
- `getSnapshotTotalSupply()`: Snapshot total supply
- `getSnapshotAddresses()`: List of addresses included in snapshot

### 4. Account Management System

#### Address Registration

- `registerAddress()`: Manual address registration
- `unregisterAddress()`: Cancel address registration
- Auto Registration: Automatic recipient registration during token transfer

#### Account Control

- `freezeAccount()`: Freeze account
- `unfreezeAccount()`: Unfreeze account
- `pause()`/`unpause()`: Pause entire contract

## Security Architecture

### 1. Multi-layer Security System

#### Reentrancy Attack Prevention

```solidity
modifier nonReentrant
```

- Applied to all state-changing functions
- Uses OpenZeppelin ReentrancyGuard

#### Access Control

```solidity
modifier onlyOwner        // Owner only
modifier onlyApproved     // Approved addresses only
modifier whenNotPaused    // When not paused
modifier notFrozen        // Non-frozen accounts only
```

### 2. Upgrade Security

#### UUPS Pattern

```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
```

- Only owner can upgrade
- State preservation through proxy pattern

#### Storage Gap

```solidity
uint256[50] private __gap;
```

- Reserved space for future state variable additions

## Gas Optimization

### 1. Efficient Data Structures

#### Lock Amount Caching

```solidity
mapping(address => uint256) public lockedAmount;
```

- Before: O(n) array traversal → Now: O(1) direct lookup
- 90% gas cost savings

#### Array Management Optimization

```solidity
// Efficient element removal
function _removeLock(address holder, uint256 idx) internal {
    // Move last element to current position
    timelockList[holder][idx] = timelockList[holder][lastIndex];
    timelockList[holder].pop();
}
```

### 2. Batch Processing

#### Auto Unlock

- Release all expired locks in a single transaction
- Improved efficiency through gas cost distribution

#### Multi-address Snapshot

- Add multiple addresses to snapshot at once
- Minimize management costs

## Deployment and Initialization

### 1. Proxy Deployment

#### Implementation Deployment

```solidity
// Deploy Implementation contract
LockToken implementation = new LockToken();
```

#### Proxy Initialization

```solidity
// Initialize through proxy
initialize(
    "EDENA",          // Token name
    "EDENA",          // Symbol
    1000000000,       // Total supply (ETH units)
    ownerAddress      // Initial owner
);
```

### 2. Initial Setup

#### Basic Lock Settings

```solidity
setLockupDays(90);              // Default 90-day lock
setAutoUnlockEnabled(true);     // Enable auto unlock
```

## Token Economics

### 1. Supply Management

#### Fixed Supply

- Total supply set during initialization
- `mint()` function disabled (for security reasons)
- Deflationary capability through `burn()` function

#### Lock Ratio

```solidity
function getLockSummary() public view returns (
    uint256 totalLockedAddresses,   // Number of locked addresses
    uint256 totalLockedAmount,      // Total locked amount
    uint256 totalLockCount          // Total lock count
);
```

## Developer API

### Lock Management API

```solidity
// Lock creation
function lock(address holder, uint256 value, uint256 releaseTime) external;
function transferWithLock(address holder, uint256 value, uint256 releaseTime) external;
function transferWithLockEasy(address holder, uint256 valueEth, uint256 lockupDays) external;

// Lock release
function claim() external returns (uint256);
function manualUnlock(address holder) external returns (uint256);

// Lock queries
function getLockedBalance(address owner) external view returns (uint256);
function getAvailableBalance(address owner) external view returns (uint256);
function getLockDetails(address holder) external view returns (
    uint256 lockCount,
    uint256 totalLockedAmount,
    uint256[] memory releaseTimes,
    uint256[] memory amounts
);
```

### Snapshot API

```solidity
// Snapshot creation
function snapshot() external onlyOwner returns (uint256);
function addAddressToSnapshot(address _address, uint256 snapshotId) external;

// Snapshot queries
function balanceOfAt(address account, uint256 snapshotId) external view returns (uint256);
function getSnapshotAddresses(uint256 snapshotId) external view returns (address[] memory);
```
