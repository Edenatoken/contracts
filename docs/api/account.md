# Account Management API

The account management system provides comprehensive tools for managing addresses, permissions, and account states within the EDENA Token V2 ecosystem.

## Core Components

### Address Registration System

The contract maintains a registry of addresses for efficient tracking and snapshot management.

```solidity
address[] public addressList;
mapping(address => bool) public isAddressRegistered;
```

### Account State Management

Individual accounts can be controlled through various state flags:

```solidity
mapping(address => bool) public frozenAccount;
```

### Approval System (Approvable)

The contract implements a custom approval system for granular permission control:

```solidity
address[] approveArr;
```

## Address Registration Functions

### `registerAddress()`

Manually registers an address for tracking and snapshot inclusion.

```solidity
function registerAddress(address _address) public onlyOwner
```

**Parameters:**

- `_address`: Address to register

**Requirements:**

- Caller must be contract owner
- Address cannot be zero address
- Address must not be already registered

**Use Cases:**

- Prepare addresses for upcoming snapshots
- Ensure important addresses are tracked
- Manual registration for governance participants

**Example:**

```solidity
// Register important stakeholder
lockToken.registerAddress(stakeholderAddress);

// Verify registration
bool isRegistered = lockToken.isAddressRegistered(stakeholderAddress);
require(isRegistered, "Address not registered");
```

### `unregisterAddress()`

Removes an address from the registry.

```solidity
function unregisterAddress(address _address) public onlyOwner
```

**Parameters:**

- `_address`: Address to unregister

**Process:**

1. Validates address is registered
2. Removes from `addressList` array (using efficient swap-and-pop)
3. Updates `isAddressRegistered` mapping

**Gas Optimization:** Uses swap-and-pop algorithm for O(1) removal

**Example:**

```solidity
// Remove inactive address
lockToken.unregisterAddress(inactiveAddress);
```

### `getRegisteredAddresses()`

Returns all currently registered addresses.

```solidity
function getRegisteredAddresses() public view returns (address[] memory)
```

**Returns:** Array of all registered addresses

**Use Cases:**

- Admin dashboard displays
- Bulk operations on registered addresses
- Audit and compliance reporting

**Example:**

```solidity
address[] memory registeredAddresses = lockToken.getRegisteredAddresses();
console.log("Total registered addresses:", registeredAddresses.length);

for (uint i = 0; i < registeredAddresses.length; i++) {
    console.log("Address", i, ":", registeredAddresses[i]);
}
```

### `getRegisteredAddressCount()`

Returns the number of registered addresses.

```solidity
function getRegisteredAddressCount() public view returns (uint256)
```

**Gas Efficient:** Returns count without loading full array

**Example:**

```solidity
uint256 count = lockToken.getRegisteredAddressCount();
console.log("Total registered addresses:", count);
```

### Auto-Registration

Addresses are automatically registered during token transfers:

```solidity
function _registerAddressIfNeeded(address _address) internal {
    if (_address != address(0) && !isAddressRegistered[_address]) {
        addressList.push(_address);
        isAddressRegistered[_address] = true;
    }
}
```

**Triggered by:**

- `transfer()` - Recipient auto-registered
- `transferFrom()` - Recipient auto-registered
- `transferWithLock()` - Recipient auto-registered

## Account Control Functions

### `freezeAccount()`

Freezes an account, preventing all token operations.

```solidity
function freezeAccount(address holder) public onlyOwner
```

**Parameters:**

- `holder`: Address to freeze

**Effects:**

- Prevents all token transfers from the account
- Blocks the account from claiming locks
- Stops the account from participating in token operations

**Use Cases:**

- Regulatory compliance
- Security incident response
- Dispute resolution
- Anti-money laundering measures

**Example:**

```solidity
// Freeze suspicious account
lockToken.freezeAccount(suspiciousAddress);

// Verify freeze status
bool isFrozen = lockToken.frozenAccount(suspiciousAddress);
require(isFrozen, "Account should be frozen");
```

**Event Emitted:**

```solidity
event Freeze(address indexed holder);
```

### `unfreezeAccount()`

Unfreezes a previously frozen account.

```solidity
function unfreezeAccount(address holder) public onlyOwner
```

**Parameters:**

- `holder`: Address to unfreeze

**Example:**

```solidity
// Unfreeze after investigation
lockToken.unfreezeAccount(previouslyFrozenAddress);

// Verify unfreeze
bool isFrozen = lockToken.frozenAccount(previouslyFrozenAddress);
require(!isFrozen, "Account should be unfrozen");
```

**Event Emitted:**

```solidity
event Unfreeze(address indexed holder);
```

## Approval System Functions

### `addApproveArr()`

Adds an address to the approved list for special permissions.

```solidity
function addApproveArr(address _approveAddress) public onlyOwner
```

**Parameters:**

- `_approveAddress`: Address to approve

**Requirements:**

- Address cannot be zero address
- Address must not be already approved

**Approved Permissions:**

- Create locks via `lock()`
- Transfer with locks via `transferWithLock()`
- Manually unlock others' tokens via `manualUnlock()`

**Example:**

```solidity
// Approve vesting contract
lockToken.addApproveArr(vestingContractAddress);

// Approve DAO governance contract
lockToken.addApproveArr(daoGovernanceAddress);
```

### `removeApproveArr()`

Removes an address from the approved list.

```solidity
function removeApproveArr(address _approveAddress) public onlyOwner
```

**Parameters:**

- `_approveAddress`: Address to remove from approved list

**Gas Optimization:** Uses efficient swap-and-pop removal

**Example:**

```solidity
// Remove approval from old contract
lockToken.removeApproveArr(oldContractAddress);
```

### `isApproved()`

Checks if an address has approval permissions.

```solidity
function isApproved(address checkAddress) public view returns (bool)
```

**Parameters:**

- `checkAddress`: Address to check

**Returns:** `true` if address is approved or is the contract owner

**Auto-Approval:** Contract owner is automatically approved

**Example:**

```solidity
// Check if address can perform admin operations
bool canManageLocks = lockToken.isApproved(managerAddress);
if (canManageLocks) {
    // Allow lock management operations
}
```

### `getApprovedList()`

Returns all currently approved addresses.

```solidity
function getApprovedList() public view returns (address[] memory)
```

**Returns:** Array of approved addresses (excludes owner)

**Example:**

```solidity
address[] memory approvedAddresses = lockToken.getApprovedList();
console.log("Approved addresses count:", approvedAddresses.length);
```

## Access Control Integration

### Modifier Usage

The account management system integrates with various access control modifiers:

```solidity
modifier onlyApproved() {
    require(isApproved(msg.sender), "Must call by Owner or Approved Contract");
    _;
}

modifier notFrozen(address _holder) {
    require(!frozenAccount[_holder], "Account is frozen");
    _;
}
```

### Transfer Restrictions

Frozen accounts are automatically blocked from transfers:

```solidity
function transfer(address to, uint256 value)
    public
    override
    whenNotPaused
    notFrozen(msg.sender)  // Checks if sender is frozen
    nonReentrant
    returns (bool)
```

## Advanced Usage Patterns

### Multi-Tier Permission System

```solidity
contract TokenManagement {
    LockToken public immutable token;

    mapping(address => uint8) public permissionLevel;
    // 0: No permissions
    // 1: Can view only
    // 2: Can manage locks
    // 3: Can freeze accounts

    function grantPermissions(address user, uint8 level) external onlyOwner {
        if (level >= 2) {
            token.addApproveArr(user);
        }
        permissionLevel[user] = level;
    }
}
```

### Compliance Integration

```solidity
contract ComplianceManager {
    LockToken public immutable token;

    mapping(address => bool) public kycVerified;
    mapping(address => uint256) public riskScore;

    function updateCompliance(address user, bool verified, uint256 risk) external {
        kycVerified[user] = verified;
        riskScore[user] = risk;

        // Auto-freeze high-risk accounts
        if (risk > 80) {
            token.freezeAccount(user);
        } else if (token.frozenAccount(user) && risk < 20) {
            token.unfreezeAccount(user);
        }
    }
}
```

### Governance Integration

```solidity
contract DAOGovernance {
    LockToken public immutable token;

    function executeProposal(address target, bool freeze) external {
        require(isApproved(), "Not authorized");

        if (freeze) {
            token.freezeAccount(target);
        } else {
            token.unfreezeAccount(target);
        }
    }

    function isApproved() internal view returns (bool) {
        return token.isApproved(address(this));
    }
}
```

## Batch Operations

### Batch Address Registration

```solidity
// Custom function for batch registration
function batchRegisterAddresses(address[] memory addresses) external onlyOwner {
    for (uint i = 0; i < addresses.length; i++) {
        if (!lockToken.isAddressRegistered(addresses[i])) {
            lockToken.registerAddress(addresses[i]);
        }
    }
}
```

### Batch Freeze/Unfreeze

```solidity
// Batch freeze multiple accounts
function batchFreezeAccounts(address[] memory accounts) external onlyOwner {
    for (uint i = 0; i < accounts.length; i++) {
        if (!lockToken.frozenAccount(accounts[i])) {
            lockToken.freezeAccount(accounts[i]);
        }
    }
}
```

## Security Considerations

### Permission Escalation

- Owner permissions cannot be delegated
- Approved addresses cannot approve other addresses
- Frozen accounts cannot unfreeze themselves

### Emergency Procedures

```solidity
// Emergency freeze all operations
function emergencyFreezeAll() external onlyOwner {
    lockToken.pause(); // Pauses all operations
}

// Emergency unfreeze
function emergencyUnfreezeAll() external onlyOwner {
    lockToken.unpause();
}
```

## Events

```solidity
event Freeze(address indexed holder);
event Unfreeze(address indexed holder);
```

**Event Parameters:**

- `holder`: Address that was frozen/unfrozen

## Gas Optimization

### Efficient Array Management

The contract uses optimized array operations:

```solidity
// Efficient removal (swap-and-pop)
function removeFromArray(address[] storage array, address target) internal {
    for (uint i = 0; i < array.length; i++) {
        if (array[i] == target) {
            array[i] = array[array.length - 1];
            array.pop();
            break;
        }
    }
}
```

### State Access Patterns

- Use `isAddressRegistered` mapping for O(1) lookup
- Minimize array iterations in view functions
- Batch operations when possible

## Error Messages

| Error                              | Cause                               |
| ---------------------------------- | ----------------------------------- |
| `"Cannot register zero address"`   | Attempting to register address(0)   |
| `"Address already registered"`     | Address is already in registry      |
| `"Cannot unregister zero address"` | Attempting to unregister address(0) |
| `"Address not registered"`         | Address not in registry             |
| `"Cannot freeze zero address"`     | Attempting to freeze address(0)     |
| `"Cannot unfreeze zero address"`   | Attempting to unfreeze address(0)   |
| `"Invalid address"`                | Address validation failed           |
| `"Already approved"`               | Address already in approve list     |
| `"checkAddress is null"`           | Null address in approval check      |

## Integration Examples

### KYC Integration

```solidity
contract KYCManager {
    LockToken public immutable token;
    mapping(address => bool) public verified;

    function verifyUser(address user) external onlyKYCProvider {
        verified[user] = true;
        token.registerAddress(user);
    }

    function suspendUser(address user) external onlyKYCProvider {
        verified[user] = false;
        token.freezeAccount(user);
    }
}
```

### Multi-Contract System

```solidity
contract TokenEcosystem {
    LockToken public immutable token;

    constructor(address tokenAddress) {
        token = LockToken(tokenAddress);

        // Register this contract as approved
        token.addApproveArr(address(this));
    }

    function onboardUser(address user) external {
        // Register user for tracking
        token.registerAddress(user);

        // Additional onboarding logic...
    }
}
```

## Next Steps

- [Events Documentation](events.md) - Complete event reference
- [Integration Guide](../guides/integration.md) - System integration guide
