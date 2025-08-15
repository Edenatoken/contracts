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
        for (uint256 i = 0; i < arrCnt; i++) {
            if (approveArr[i] == _approveAddress) {
                // move last element to current position
                approveArr[i] = approveArr[arrCnt - 1];
                // decrease array length
                approveArr.pop();
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

    // Snapshot related variables
    mapping(uint256 => uint256) public snapshotTotalSupply;
    mapping(uint256 => uint256) public snapshotTimestamp;
    mapping(uint256 => mapping(address => uint256)) public snapshotBalances;
    uint256 public currentSnapshotId;

    // Address management
    address[] public addressList;
    mapping(address => bool) public isAddressRegistered;
    mapping(uint256 => address[]) public snapshotAddresses;

    // Storage gap - reserved space for future upgrades
    uint256[50] private __gap;

    // Events
    event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator);
    event Unlock(address indexed holder, uint256 value, address indexed operator);
    event Freeze(address indexed holder);
    event Unfreeze(address indexed holder);
    event SnapshotCreated(uint256 indexed snapshotId, uint256 totalAddresses, uint256 totalSupply);

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
        require(balanceOf(holder) - lockedAmount[holder] >= value, "Insufficient unlocked balance for lock");

        lockedAmount[holder] += value;
        timelockList[holder].push(LockInfo(releaseTime, value));
        emit Lock(holder, value, releaseTime, msg.sender);
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
    function _autoUnlock(address holder) internal returns (uint256) {
        require(holder != address(0), "Cannot unlock zero address");
        uint256 i = 0;
        uint256 unlockedCount = 0;
        while (i < timelockList[holder].length) {
            if (block.timestamp >= timelockList[holder][i]._releaseTime) {
                _removeLock(holder, i);
                unlockedCount++;
            } else {
                i++;
            }
        }
        return unlockedCount;
    }

    // Override hook to allow transfer only for unlocked tokens in transfer/transferFrom
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20Upgradeable)
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
        lockupDays = _lockupDays;
    }

    function setAutoUnlockEnabled(bool _enabled) public onlyOwner {
        autoUnlockEnabled = _enabled;
    }

    // Address management functions
    function registerAddress(address _address) public onlyOwner {
        require(_address != address(0), "Cannot register zero address");
        require(!isAddressRegistered[_address], "Address already registered");
        
        addressList.push(_address);
        isAddressRegistered[_address] = true;
    }

    function unregisterAddress(address _address) public onlyOwner {
        require(_address != address(0), "Cannot unregister zero address");
        require(isAddressRegistered[_address], "Address not registered");
        
        // Remove from addressList
        uint256 length = addressList.length;
        for (uint256 i = 0; i < length; i++) {
            if (addressList[i] == _address) {
                // move last element to current position
                addressList[i] = addressList[length - 1];
                addressList.pop();
                break;
            }
        }
        
        isAddressRegistered[_address] = false;
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

    // getLockedBalance only returns lockedAmount, so it's OK
    function getLockedBalance(address owner) public view returns (uint256) {
        return lockedAmount[owner];
    }

    function getLockTotal(address holder) public view returns (uint256) {
        uint256 lockTotal = 0;
        for (uint256 idx = 0; idx < timelockList[holder].length; idx++) {
            if (timelockList[holder][idx]._releaseTime > block.timestamp) {
                lockTotal += timelockList[holder][idx]._amount;
            }
        }
        return lockTotal;
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

    // Lock related functions
    function lock(
        address holder,
        uint256 value,
        uint256 releaseTime
    ) public onlyApproved nonReentrant returns (bool) {
        require(holder != address(0), "Cannot lock zero address");
        require(value > 0, "Lock amount must be greater than 0");
        require(releaseTime > block.timestamp, "Release time must be in the future");
        require(balanceOf(holder) >= value, "There is not enough balances of holder.");
        _lock(holder, value, releaseTime);
        return true;
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
    ) public override whenNotPaused notFrozen(from) nonReentrant returns (bool) {
        require(from != address(0), "Cannot transfer from zero address");
        require(to != address(0), "Cannot transfer to zero address");
        require(value > 0, "Transfer amount must be greater than 0");
        if (autoUnlockEnabled && timelockList[from].length > 0) {
            _autoUnlock(from);
        }
        _registerAddressIfNeeded(to);
        return super.transferFrom(from, to, value);
    }

    // Snapshot related functions
    function snapshot() public onlyOwner returns (uint256) {
        uint256 snapshotId = currentSnapshotId + 1;
        currentSnapshotId = snapshotId;
        
        uint256 totalSupply = totalSupply();
        snapshotTotalSupply[snapshotId] = totalSupply;
        snapshotTimestamp[snapshotId] = block.timestamp;
        
        // Store balance of all registered addresses in snapshot (including locked quantity)
        uint256 addressCount = addressList.length;
        address[] storage snapshotAddrList = snapshotAddresses[snapshotId];
        
        for (uint256 i = 0; i < addressCount; i++) {
            address addr = addressList[i];
            uint256 balance = balanceOf(addr);
            if (balance > 0) {
                snapshotBalances[snapshotId][addr] = balance;
                snapshotAddrList.push(addr);
            }
        }
        
        emit SnapshotCreated(snapshotId, snapshotAddrList.length, totalSupply);
        return snapshotId;
    }

    // Function to manually add specific address to snapshot
    function addAddressToSnapshot(address _address, uint256 snapshotId) public onlyOwner {
        require(_address != address(0), "Cannot add zero address");
        require(snapshotId <= currentSnapshotId, "Snapshot does not exist");
        
        uint256 balance = balanceOf(_address);
        
        if (balance > 0) {
            snapshotBalances[snapshotId][_address] = balance;
            snapshotAddresses[snapshotId].push(_address);
        }
    }

    // Function to add multiple addresses to snapshot at once
    function addAddressesToSnapshot(address[] memory _addresses, uint256 snapshotId) public onlyOwner {
        require(snapshotId <= currentSnapshotId, "Snapshot does not exist");
        
        for (uint256 i = 0; i < _addresses.length; i++) {
            address addr = _addresses[i];
            if (addr != address(0)) {
                uint256 balance = balanceOf(addr);
                
                if (balance > 0) {
                    snapshotBalances[snapshotId][addr] = balance;
                    snapshotAddresses[snapshotId].push(addr);
                }
            }
        }
    }

    // Query address balance at specific snapshot (including locked quantity)
    function balanceOfAt(address account, uint256 snapshotId) public view returns (uint256) {
        return snapshotBalances[snapshotId][account];
    }

    function getSnapshotTotalSupply(uint256 snapshotId) public view returns (uint256) {
        return snapshotTotalSupply[snapshotId];
    }

    function getSnapshotTimestamp(uint256 snapshotId) public view returns (uint256) {
        return snapshotTimestamp[snapshotId];
    }

    function getSnapshotAddresses(uint256 snapshotId) public view returns (address[] memory) {
        return snapshotAddresses[snapshotId];
    }

    function getSnapshotAddressCount(uint256 snapshotId) public view returns (uint256) {
        return snapshotAddresses[snapshotId].length;
    }

    function isAddressInSnapshot(address _address, uint256 snapshotId) public view returns (bool) {
        address[] memory addresses = snapshotAddresses[snapshotId];
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == _address) {
                return true;
            }
        }
        return false;
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