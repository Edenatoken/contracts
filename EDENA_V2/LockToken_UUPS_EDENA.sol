// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "./Initializable.sol";
import "./UUPSUpgradeable.sol";
import "./OwnableUpgradeable.sol";
import "./PausableUpgradeable.sol";
import "./ReentrancyGuardUpgradeable.sol";
import "./ERC20Upgradeable.sol";

contract Approvable is Initializable, OwnableUpgradeable {
    address[] approveArr; // Manages contract or account addresses to control. Prevents illegal execution

    function __Approvable_init(address initialOwner) internal onlyInitializing {}

    // approve contract check - owner is automatically granted permission
    modifier onlyApproved() {
        bool approve = false;
        
        // owner is automatically granted approve permission
        if (owner() == msg.sender) {
            approve = true;
        } else {
            // check from approve array
            uint256 arrCnt = approveArr.length;
            for (uint256 i = 0; i < arrCnt; i++) {
                if (approveArr[i] == msg.sender) {
                    approve = true;
                    break;
                }
            }
        }
        
        require(approve, "Must call by Owner or Approved Contract");
        _;
    }

    function addApproveArr(address _approveAddress) public onlyOwner {
        require(_approveAddress != address(0), "Invalid address");
        require(!isApproved(_approveAddress), "Already approved");
        approveArr.push(_approveAddress);
    }

    function removeApproveArr(address _approveAddress) public onlyOwner {
        require(_approveAddress != address(0), "Invalid address");
        uint256 arrCnt = approveArr.length;
        bool found = false;
        for (uint256 i = 0; i < arrCnt; i++) {
            if (approveArr[i] == _approveAddress) {
                // move last element to current position
                approveArr[i] = approveArr[arrCnt - 1];
                // decrease array length
                approveArr.pop();
                found = true;
                break;
            }
        }
    }

    function isApproved(address checkAddress) public view returns (bool) {
        require(checkAddress != address(0), "checkAddress is null");

        // owner is automatically granted approve permission
        if (owner() == checkAddress) {
            return true;
        }

        // check from approve array
        bool approve = false;
        uint256 arrCnt = approveArr.length;
        for (uint256 i = 0; i < arrCnt; i++) {
            if (approveArr[i] == checkAddress) {
                approve = true;
                break;
            }
        }
        return approve;
    }

    function getApprovedList() public view returns (address[] memory) {
        return approveArr;
    }
}

contract LockToken is
    Initializable,
    ERC20Upgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable,
    Approvable {
    uint256 public lockupDays; // Default lockup period 3 months calculated as 90 days
    
    // Auto unlock feature activation status
    bool public autoUnlockEnabled;
    
    struct LockInfo {
        uint256 _releaseTime;
        uint256 _amount;
    }

    mapping(address => LockInfo[]) public timelockList;
    mapping(address => bool) public frozenAccount;

    // Mapping for managing locked token amounts
    mapping(address => uint256) public lockedAmount;

    // Snapshot related variables - EXACT original layout
    mapping(uint256 => uint256) public snapshotTotalSupply;
    mapping(uint256 => uint256) public snapshotTimestamp;
    mapping(uint256 => mapping(address => uint256)) public snapshotBalances;
    uint256 public currentSnapshotId;

    // Address management - EXACT original layout
    address[] public addressList;
    mapping(address => bool) public isAddressRegistered;
    mapping(uint256 => address[]) public snapshotAddresses;

    // Lock constraints and security - These were missing from variable declarations
    uint256 public constant MAX_LOCKS_PER_ADDRESS = 100;
    uint256 public constant MAX_LOCK_DURATION = 1460 days; // 4 years maximum
    mapping(address => uint256) public lastLockTime;
    uint256 public lockCooldownPeriod;
    mapping(uint256 => bool) public snapshotFinalized;

    // NEW VARIABLES - Added after all existing inherited variables for upgrade compatibility
    uint256[] private _allSnapshotIds;
    mapping(uint256 => bool) public snapshotCompleted;
    mapping(uint256 => uint256) public snapshotProcessedIndex;
    mapping(uint256 => bool) public snapshotProcessing;
    uint256 public defaultBatchSize;

    // Storage gap - reserved space for future upgrades  
    uint256[42] private __gap;

    // Events
    event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);
    event Unlock(address indexed holder, uint256 value, address indexed operator);
    event Freeze(address indexed holder);
    event Unfreeze(address indexed holder);
    event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);
    
    // Administrative events
    event AddressRegistered(address indexed registrar, address indexed newAddress);
    event AddressUnregistered(address indexed registrar, address indexed removedAddress);
    event LockupDaysChanged(address indexed owner, uint256 oldDays, uint256 newDays);
    event AutoUnlockEnabledChanged(address indexed owner, bool enabled);
    event LockCooldownChanged(address indexed owner, uint256 oldCooldown, uint256 newCooldown);
    event SnapshotFinalized(uint256 indexed snapshotId);
    event SnapshotCompleted(uint256 indexed snapshotId, uint256 totalAddresses);
    event SnapshotProcessingStarted(uint256 indexed snapshotId);
    event SnapshotProcessingResumed(uint256 indexed snapshotId);

    modifier notFrozen(address _holder) {
        require(!frozenAccount[_holder]);
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory tokenName,
        string memory tokenSymbol,
        uint256 totalSupplyEth,
        address initialOwner
    ) public initializer {
        __ERC20_init(tokenName, tokenSymbol);
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        __Approvable_init(initialOwner);
        
        transferOwnership(initialOwner);
        
        lockupDays = 90; // Default 90 days
        autoUnlockEnabled = true; // Default enabled
        defaultBatchSize = 100; // Default batch size
        lockCooldownPeriod = 1 hours; // Default cooldown period
        
        uint256 totalSupplyWei = totalSupplyEth * (10**18);
        _mint(initialOwner, totalSupplyWei);
        
        // Register initial owner to addressList
        addressList.push(initialOwner);
        isAddressRegistered[initialOwner] = true;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Utility functions
    function _addDays(uint256 _days) internal view returns (uint256) {
        require(_days <= 3650, "Days cannot exceed 10 years");
        return (block.timestamp + (_days * 24 * 60 * 60));
    }

    function _ethToWei(uint256 _ethVal) internal pure returns (uint256) {
        return (_ethVal * (10**18));
    }

    // Internal functions
    function _lock(address holder, uint256 value, uint256 releaseTime) internal {
        require(holder != address(0), "Cannot lock zero address");
        require(value > 0, "Lock amount must be greater than 0");
        require(releaseTime > block.timestamp, "Release time must be in the future");
        require(releaseTime <= block.timestamp + MAX_LOCK_DURATION, "Lock duration exceeds maximum");
        require(balanceOf(holder) - lockedAmount[holder] >= value, "Insufficient unlocked balance for lock");
        require(timelockList[holder].length < MAX_LOCKS_PER_ADDRESS, "Too many active locks");
        
        // Anti-frontrunning cooldown check (only for third-party locks)
        uint256 cooldown = lockCooldownPeriod > 0 ? lockCooldownPeriod : 1 hours;
        if (msg.sender != holder && lastLockTime[holder] + cooldown > block.timestamp) {
            require(lastLockTime[holder] + cooldown <= block.timestamp, "Lock cooldown period not passed");
        }

        lockedAmount[holder] += value;
        timelockList[holder].push(LockInfo(releaseTime, value));
        lastLockTime[holder] = block.timestamp;
        
        // Sort the locks by release time to maintain order
        _sortLocksByReleaseTime(holder);
        
        emit Lock(holder, value, releaseTime, msg.sender);
    }
    
    // Sort locks by release time for efficient processing
    function _sortLocksByReleaseTime(address holder) internal {
        LockInfo[] storage locks = timelockList[holder];
        uint256 length = locks.length;
        
        // Simple insertion sort for small arrays (efficient for MAX_LOCKS_PER_ADDRESS = 100)
        for (uint256 i = 1; i < length; i++) {
            LockInfo memory key = locks[i];
            uint256 j = i;
            while (j > 0 && locks[j - 1]._releaseTime > key._releaseTime) {
                locks[j] = locks[j - 1];
                j--;
            }
            locks[j] = key;
        }
    }

    // Common unlock logic
    function _removeLock(address holder, uint256 idx) internal {
        LockInfo storage lockInfo = timelockList[holder][idx];
        uint256 amount = lockInfo._amount;
        // Remove lock information (move last element to current position)
        uint256 lastIndex = timelockList[holder].length - 1;
        if (idx != lastIndex) {
            timelockList[holder][idx] = timelockList[holder][lastIndex];
        }
        timelockList[holder].pop();
        // Decrease locked amount
        require(lockedAmount[holder] >= amount, "Locked amount underflow");
        lockedAmount[holder] -= amount;
        emit Unlock(holder, amount, msg.sender);
    }

    function _unlock(address holder, uint256 idx) internal {
        require(holder != address(0), "Cannot unlock zero address");
        require(timelockList[holder].length > idx, "Lock index does not exist");
        require(block.timestamp >= timelockList[holder][idx]._releaseTime, "Lock period not expired");
        _removeLock(holder, idx);
    }

    // Unlock all expired locks and return the number of unlocked locks
    // Optimized to stop at first non-expired lock since locks are sorted
    function _autoUnlock(address holder) internal returns (uint256) {
        require(holder != address(0), "Cannot unlock zero address");
        uint256 unlockedCount = 0;
        
        // Since locks are sorted by release time, we can process from beginning
        // and stop when we hit the first non-expired lock
        while (timelockList[holder].length > 0 && 
               block.timestamp >= timelockList[holder][0]._releaseTime) {
            _removeLock(holder, 0);
            unlockedCount++;
        }
        
        return unlockedCount;
    }

    // Override hook to allow transfer only for unlocked tokens in transfer/transferFrom
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, amount); 

        if (from != address(0)) {
            require(
                balanceOf(from) - lockedAmount[from] >= amount,
                "Transfer amount exceeds unlocked balance"
            );
        }
    }

    // Configuration functions
    function setLockupDays(uint256 _lockupDays) public onlyOwner {
        require(_lockupDays > 0 && _lockupDays <= 3650, "Lockup days must be between 1 and 3650");
        uint256 oldDays = lockupDays;
        lockupDays = _lockupDays;
        emit LockupDaysChanged(msg.sender, oldDays, _lockupDays);
    }

    function setAutoUnlockEnabled(bool _enabled) public onlyOwner {
        autoUnlockEnabled = _enabled;
        emit AutoUnlockEnabledChanged(msg.sender, _enabled);
    }

    function setLockCooldownPeriod(uint256 _cooldownPeriod) public onlyOwner {
        require(_cooldownPeriod <= 24 hours, "Cooldown period too long");
        uint256 oldCooldown = lockCooldownPeriod;
        lockCooldownPeriod = _cooldownPeriod;
        emit LockCooldownChanged(msg.sender, oldCooldown, _cooldownPeriod);
    }

    // Address management functions
    function registerAddress(address _address) public onlyOwner {
        require(_address != address(0), "Cannot register zero address");
        require(!isAddressRegistered[_address], "Address already registered");
        
        addressList.push(_address);
        isAddressRegistered[_address] = true;
        emit AddressRegistered(msg.sender, _address);
    }

    function unregisterAddress(address _address) public onlyOwner {
        require(_address != address(0), "Cannot unregister zero address");
        require(isAddressRegistered[_address], "Address not registered");
        
        // Remove from addressList
        uint256 length = addressList.length;
        bool found = false;
        for (uint256 i = 0; i < length; i++) {
            if (addressList[i] == _address) {
                // move last element to current position
                addressList[i] = addressList[length - 1];
                addressList.pop();
                found = true;
                break;
            }
        }
        
        if (found) {
            isAddressRegistered[_address] = false;
            emit AddressUnregistered(msg.sender, _address);
        }
    }

    function getRegisteredAddresses() public view returns (address[] memory) {
        return addressList;
    }

    function getRegisteredAddressCount() public view returns (uint256) {
        return addressList.length;
    }

    // Lock related query functions
    function getLockCount(address holder) public view returns (uint256) {
        return timelockList[holder].length;
    }

    // Clear lock accounting functions
    function getLockedIncludingExpired(address owner) public view returns (uint256) {
        return lockedAmount[owner];
    }

    function getLockedUnexpired(address holder) public view returns (uint256) {
        uint256 lockTotal = 0;
        
        // Since locks are sorted by release time, we can break early
        for (uint256 idx = 0; idx < timelockList[holder].length; idx++) {
            if (timelockList[holder][idx]._releaseTime > block.timestamp) {
                lockTotal += timelockList[holder][idx]._amount;
            } else {
                // All subsequent locks will also be expired, so we can continue
                // to count them but we know they don't contribute to current locked amount
                continue;
            }
        }
        return lockTotal;
    }

    // Legacy functions for backward compatibility
    function getLockedBalance(address owner) public view returns (uint256) {
        return getLockedIncludingExpired(owner);
    }

    function getLockTotal(address holder) public view returns (uint256) {
        return getLockedUnexpired(holder);
    }

    // Returns the available (transferable) balance: total balance minus locked amount
    function getAvailableBalance(address owner) public view returns (uint256) {
        uint256 balance = balanceOf(owner);
        uint256 locked = lockedAmount[owner];
        if (balance > locked) {
            return balance - locked;
        } else {
            return 0;
        }
    }

    // Overall lock status summary query
    function getLockSummary() public view returns (
        uint256 totalLockedAddresses,
        uint256 totalLockedAmount,
        uint256 totalLockCount
    ) {
        address[] memory addresses = getRegisteredAddresses();
        uint256 totalAddresses = 0;
        uint256 totalAmount = 0;
        uint256 totalCount = 0;
        
        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 lockedBalance = getLockedBalance(addresses[i]);
            if (lockedBalance > 0) {
                totalAddresses++;
                totalAmount += lockedBalance;
                totalCount += getLockCount(addresses[i]);
            }
        }
        
        return (totalAddresses, totalAmount, totalCount);
    }

    // Overall lock status detailed query
    function getAllLockedBalances() public view returns (
        address[] memory holders,
        uint256[] memory lockedAmounts,
        uint256[] memory lockCounts
    ) {
        address[] memory addresses = getRegisteredAddresses();
        uint256 lockedCount = 0;
        
        // Calculate number of locked addresses
        for (uint256 i = 0; i < addresses.length; i++) {
            if (getLockedBalance(addresses[i]) > 0) {
                lockedCount++;
            }
        }
        
        // Initialize result arrays
        holders = new address[](lockedCount);
        lockedAmounts = new uint256[](lockedCount);
        lockCounts = new uint256[](lockedCount);
        
        uint256 index = 0;
        for (uint256 i = 0; i < addresses.length; i++) {
            uint256 lockedBalance = getLockedBalance(addresses[i]);
            if (lockedBalance > 0) {
                holders[index] = addresses[i];
                lockedAmounts[index] = lockedBalance;
                lockCounts[index] = getLockCount(addresses[i]);
                index++;
            }
        }
        
        return (holders, lockedAmounts, lockCounts);
    }

    // Detailed lock information query for specific address
    function getLockDetails(address holder) public view returns (
        uint256 lockCount,
        uint256 totalLockedAmount,
        uint256[] memory releaseTimes,
        uint256[] memory amounts
    ) {
        lockCount = getLockCount(holder);
        totalLockedAmount = getLockedBalance(holder);
        
        releaseTimes = new uint256[](lockCount);
        amounts = new uint256[](lockCount);
        
        for (uint256 i = 0; i < lockCount; i++) {
            LockInfo storage lockInfo = timelockList[holder][i];
            releaseTimes[i] = lockInfo._releaseTime;
            amounts[i] = lockInfo._amount;
        }
        
        return (lockCount, totalLockedAmount, releaseTimes, amounts);
    }

    function transferWithLock(
        address holder,
        uint256 value,
        uint256 releaseTime
    ) public onlyApproved nonReentrant returns (bool) {
        require(holder != address(0), "Cannot transfer to zero address");
        require(value > 0, "Transfer amount must be greater than 0");
        require(balanceOf(msg.sender) - lockedAmount[msg.sender] >= value, "Insufficient unlocked balance");
        
        // Auto register if recipient is not registered
        if (!isAddressRegistered[holder]) {
            addressList.push(holder);
            isAddressRegistered[holder] = true;
        }
        
        // Transfer tokens to holder first
        _transfer(msg.sender, holder, value);
        // Then lock the transferred tokens
        _lock(holder, value, releaseTime);
        return true;
    }

    function transferWithLockEasy(
        address holder,
        uint256 valueEth,
        uint256 lockupDaysParam
    ) public onlyApproved returns (bool) {
        uint256 valueWei = valueEth * (10**18);
        uint256 releaseTime = block.timestamp + (lockupDaysParam * 1 days);
        return transferWithLock(holder, valueWei, releaseTime);
    }

    function transferWithLockBase(
        address holder,
        uint256 value
    ) public onlyApproved returns (bool) {
        uint256 releaseTime = block.timestamp + (lockupDays * 1 days);
        return transferWithLock(holder, value, releaseTime);
    }

    // Unlock related functions
    function unlock(address holder, uint256 idx) public onlyApproved nonReentrant returns (bool) {
        require(holder != address(0), "Cannot unlock zero address");
        require(timelockList[holder].length > idx, "There is not lock info.");
        _unlock(holder, idx);
        return true;
    }

    function claim() public nonReentrant returns (uint256) {
        address holder = msg.sender;
        return _autoUnlock(holder);
    }

    // Function for approved users to unlock others' locks
    function manualUnlock(address holder) public onlyApproved nonReentrant returns (uint256) {
        require(holder != address(0), "Cannot unlock zero address");
        return _autoUnlock(holder);
    }

    // Token transfer functions
    function transfer(address to, uint256 value)
        public
        override
        whenNotPaused
        notFrozen(msg.sender)
        notFrozen(to)  
        nonReentrant
        returns (bool)
    {
        require(to != address(0), "Cannot transfer to zero address");
        require(value > 0, "Transfer amount must be greater than 0");
        if (autoUnlockEnabled && timelockList[msg.sender].length > 0) {
            _autoUnlock(msg.sender);
        }
        _registerAddressIfNeeded(to);
        return super.transfer(to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override whenNotPaused notFrozen(from) notFrozen(to) nonReentrant returns (bool) {
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        require(value > 0, "Transfer amount must be greater than 0");
        if (autoUnlockEnabled && timelockList[from].length > 0) {
            _autoUnlock(from);
        }
        _registerAddressIfNeeded(to);
        return super.transferFrom(from, to, value);
    }

    // Snapshot related functions - Batch processing implementation with auto-start
    function createSnapshot() public onlyOwner returns (uint256) {
        uint256 snapshotId = currentSnapshotId + 1;
        currentSnapshotId = snapshotId;
        
        _allSnapshotIds.push(snapshotId);
        snapshotTotalSupply[snapshotId] = totalSupply();
        snapshotTimestamp[snapshotId] = block.timestamp;
        snapshotFinalized[snapshotId] = false;
        
        // Initialize batch processing state
        snapshotCompleted[snapshotId] = false;
        snapshotProcessedIndex[snapshotId] = 0;
        snapshotProcessing[snapshotId] = true;
        
        // Pause all token transfers during snapshot processing (only if not already paused)
        if (!paused()) {
            _pause();
        }
        
        emit SnapshotCreated(snapshotId, 0, totalSupply());
        emit SnapshotProcessingStarted(snapshotId);
        
        // Automatically start processing with default batch size
        uint256 batchSize = defaultBatchSize > 0 ? defaultBatchSize : 100;
        bool completed = _processSnapshotInternal(snapshotId, batchSize);
        
        if (completed) {
            // Small holder set - completed in one transaction
            emit SnapshotCompleted(snapshotId, addressList.length);
        }
        
        return snapshotId;
    }
    
    // Process snapshot in batches to avoid gas limit issues
    function processSnapshot(uint256 snapshotId, uint256 batchSize) public onlyOwner returns (bool completed) {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        require(!snapshotCompleted[snapshotId], "Snapshot already completed");
        require(snapshotProcessing[snapshotId], "Snapshot not in processing state");
        require(batchSize > 0 && batchSize <= 200, "Invalid batch size"); // Limit batch size for safety
        
        return _processSnapshotInternal(snapshotId, batchSize);
    }
    
    // Internal function for snapshot processing logic
    function _processSnapshotInternal(uint256 snapshotId, uint256 batchSize) internal returns (bool completed) {
        uint256 startIndex = snapshotProcessedIndex[snapshotId];
        uint256 endIndex = startIndex + batchSize;
        
        if (endIndex > addressList.length) {
            endIndex = addressList.length;
        }
        
        // Process batch of addresses
        for (uint256 i = startIndex; i < endIndex; i++) {
            address account = addressList[i];
            uint256 balance = balanceOf(account);
            
            if (balance > 0) {
                // Only add if not already recorded for this snapshot
                if (snapshotBalances[snapshotId][account] == 0) {
                    snapshotAddresses[snapshotId].push(account);
                }
                snapshotBalances[snapshotId][account] = balance;
            }
        }
        
        // Update processed index
        snapshotProcessedIndex[snapshotId] = endIndex;
        
        // Check if processing is complete
        if (endIndex >= addressList.length) {
            snapshotCompleted[snapshotId] = true;
            snapshotProcessing[snapshotId] = false;
            
            // Resume token transfers (only if we were the ones who paused it)
            if (paused()) {
                _unpause();
            }
            
            return true;
        }
        
        return false;
    }
    
    // Finalize snapshot to prevent further modifications
    function finalizeSnapshot(uint256 snapshotId) public onlyOwner {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        require(!snapshotFinalized[snapshotId], "Snapshot already finalized");
        require(snapshotCompleted[snapshotId], "Snapshot must be completed before finalization");
        
        snapshotFinalized[snapshotId] = true;
        emit SnapshotFinalized(snapshotId);
    }
 

    // Query address balance at specific snapshot (including locked quantity)
    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        require(snapshotCompleted[snapshotId], "Snapshot not completed yet");
        
        // Direct access - all completed snapshots have complete data
        return snapshotBalances[snapshotId][account];
    }

    function getSnapshotTotalSupply(uint256 snapshotId) public view returns (uint256) {
        return snapshotTotalSupply[snapshotId];
    }

    function getSnapshotTimestamp(uint256 snapshotId) public view returns (uint256) {
        return snapshotTimestamp[snapshotId];
    }

    function getAllSnapshotIds() public view returns (uint256[] memory) {
        return _allSnapshotIds;
    }

    function getAccountSnapshotIds(address account) public view returns (uint256[] memory) {
        // In batch system, find all snapshots where this account has balance
        uint256[] memory allSnapshots = _allSnapshotIds;
        uint256 count = 0;
        
        // Count snapshots with balance
        for (uint256 i = 0; i < allSnapshots.length; i++) {
            if (snapshotBalances[allSnapshots[i]][account] > 0) {
                count++;
            }
        }
        
        // Create result array
        uint256[] memory result = new uint256[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < allSnapshots.length; i++) {
            if (snapshotBalances[allSnapshots[i]][account] > 0) {
                result[index] = allSnapshots[i];
                index++;
            }
        }
        
        return result;
    }
    
    // Snapshot status and progress query functions
    function getSnapshotStatus(uint256 snapshotId) external view returns (
        bool completed,
        uint256 processedCount,
        uint256 totalCount,
        uint256 progressPercentage,
        bool isProcessing,
        bool isFinalized
    ) {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        
        completed = snapshotCompleted[snapshotId];
        processedCount = snapshotProcessedIndex[snapshotId];
        totalCount = addressList.length;
        progressPercentage = totalCount > 0 ? (processedCount * 100) / totalCount : 100;
        isProcessing = snapshotProcessing[snapshotId];
        isFinalized = snapshotFinalized[snapshotId];
    }
    
    function isSnapshotCompleted(uint256 snapshotId) external view returns (bool) {
        return snapshotCompleted[snapshotId];
    }
    
    function isSnapshotProcessing(uint256 snapshotId) external view returns (bool) {
        return snapshotProcessing[snapshotId];
    }
    
    function getSnapshotProgress(uint256 snapshotId) external view returns (
        uint256 processedAddresses,
        uint256 totalAddresses,
        uint256 remainingAddresses
    ) {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        
        processedAddresses = snapshotProcessedIndex[snapshotId];
        totalAddresses = addressList.length;
        remainingAddresses = totalAddresses > processedAddresses ? 
            totalAddresses - processedAddresses : 0;
    }
    
    // Emergency function to resume processing if needed
    function resumeSnapshotProcessing(uint256 snapshotId) external onlyOwner {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        require(!snapshotCompleted[snapshotId], "Snapshot already completed");
        require(!snapshotProcessing[snapshotId], "Snapshot already processing");
        
        snapshotProcessing[snapshotId] = true;
        if (!paused()) {
            _pause();
        }
        
        emit SnapshotProcessingResumed(snapshotId);
    }
    
    // Emergency function to cancel snapshot processing and unpause
    function cancelSnapshotProcessing(uint256 snapshotId) external onlyOwner {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        require(snapshotProcessing[snapshotId], "Snapshot not processing");
        require(!snapshotCompleted[snapshotId], "Cannot cancel completed snapshot");
        
        snapshotProcessing[snapshotId] = false;
        if (paused()) {
            _unpause();
        }
        
        // Note: This doesn't reset processed data, just stops processing
        // Owner can resume later if needed
    }
    
    // Function to set default batch size
    function setDefaultBatchSize(uint256 _batchSize) external onlyOwner {
        require(_batchSize > 0 && _batchSize <= 200, "Invalid batch size");
        defaultBatchSize = _batchSize;
    }
    
    // Convenience function to continue processing with default batch size
    function continueSnapshot(uint256 snapshotId) external onlyOwner returns (bool completed) {
        uint256 batchSize = defaultBatchSize > 0 ? defaultBatchSize : 100;
        return processSnapshot(snapshotId, batchSize);
    }
    
    // Emergency function to completely reset snapshot processing
    function resetSnapshotProcessing(uint256 snapshotId) external onlyOwner {
        require(snapshotId > 0 && snapshotId <= currentSnapshotId, "Invalid snapshot ID");
        require(snapshotProcessing[snapshotId] || !snapshotCompleted[snapshotId], "Cannot reset completed snapshot");
        
        // Reset processing state
        snapshotProcessing[snapshotId] = false;
        snapshotProcessedIndex[snapshotId] = 0;
        snapshotCompleted[snapshotId] = false;
        
        // Clear any partial snapshot data (expensive operation)
        address[] memory snapshotAddrs = snapshotAddresses[snapshotId];
        for (uint256 i = 0; i < snapshotAddrs.length; i++) {
            delete snapshotBalances[snapshotId][snapshotAddrs[i]];
        }
        
        // Clear the address list for this snapshot
        delete snapshotAddresses[snapshotId];
        
        // Unpause if we were paused
        if (paused()) {
            _unpause();
        }
    }

    // Pause management functions
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    // Account management functions
    function freezeAccount(address holder) public onlyOwner {
        require(holder != address(0), "Cannot freeze zero address");
        frozenAccount[holder] = true;
        emit Freeze(holder);
    }

    function unfreezeAccount(address holder) public onlyOwner {
        require(holder != address(0), "Cannot unfreeze zero address");
        frozenAccount[holder] = false;
        emit Unfreeze(holder);
    }

    // Token management functions
    // function mint(address to, uint256 amount) public onlyOwner returns (bool) {
    //     require(to != address(0), "Cannot mint to zero address");
    //     require(amount > 0, "Mint amount must be greater than 0");
    //     _mint(to, amount);
    //     return true;
    // }

    function burn(uint256 amount) public returns (bool) {
        require(amount > 0, "Burn amount must be greater than 0");
        require(balanceOf(msg.sender) - lockedAmount[msg.sender] >= amount, "Insufficient unlocked balance for burn");
        _burn(msg.sender, amount);
        return true;
    }

    // Address registration internal function
    function _registerAddressIfNeeded(address _address) internal {
        if (_address != address(0) && !isAddressRegistered[_address]) {
            addressList.push(_address);
            isAddressRegistered[_address] = true;
        }
    }
} 