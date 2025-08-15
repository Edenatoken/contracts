# Integration Guide

This comprehensive guide covers integrating EDENA Token V2 into your applications, from basic wallet connections to advanced DeFi protocols.

## Integration Overview

EDENA Token V2 can be integrated into various types of applications:

- **Wallet Applications**: Basic token management
- **DeFi Protocols**: Lending, staking, governance
- **Exchange Platforms**: Trading and liquidity
- **Analytics Platforms**: Data monitoring and reporting
- **Governance Systems**: Voting and proposals

## Basic Integration

### Contract Setup

```javascript
// Contract configuration
const CONTRACT_CONFIG = {
  address: "0x...", // Replace with deployed address
  abi: LOCK_TOKEN_ABI, // Full ABI
  network: {
    name: "polygon",
    chainId: 137,
    rpc: "https://polygon-rpc.com",
  },
};

// Provider setup
import { ethers } from "ethers";

class EDENATokenIntegration {
  constructor(providerOrSigner) {
    this.provider = providerOrSigner;
    this.contract = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      providerOrSigner
    );
  }

  // Basic ERC20 functions
  async getBalance(address) {
    return await this.contract.balanceOf(address);
  }

  // Enhanced balance info
  async getDetailedBalance(address) {
    const [total, locked, available] = await Promise.all([
      this.contract.balanceOf(address),
      this.contract.getLockedBalance(address),
      this.contract.getAvailableBalance(address),
    ]);

    return {
      total: ethers.utils.formatEther(total),
      locked: ethers.utils.formatEther(locked),
      available: ethers.utils.formatEther(available),
      lockedPercentage: total.gt(0) ? locked.mul(100).div(total).toNumber() : 0,
    };
  }
}
```

## Wallet Integration

### Complete Wallet Implementation

```javascript
class EDENAWallet {
  constructor(provider, signer) {
    this.provider = provider;
    this.signer = signer;
    this.contract = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      signer
    );
    this.address = signer.address;

    // Setup event listeners
    this.setupEventListeners();
  }

  // Balance management
  async getPortfolio() {
    const [total, locked, available, lockDetails] = await Promise.all([
      this.contract.balanceOf(this.address),
      this.contract.getLockedBalance(this.address),
      this.contract.getAvailableBalance(this.address),
      this.contract.getLockDetails(this.address),
    ]);

    const [lockCount, totalLocked, releaseTimes, amounts] = lockDetails;

    // Process lock details
    const locks = [];
    for (let i = 0; i < lockCount; i++) {
      locks.push({
        id: i,
        amount: ethers.utils.formatEther(amounts[i]),
        releaseTime: releaseTimes[i].toNumber(),
        releaseDate: new Date(releaseTimes[i] * 1000),
        expired: Date.now() / 1000 > releaseTimes[i].toNumber(),
      });
    }

    return {
      balances: {
        total: ethers.utils.formatEther(total),
        locked: ethers.utils.formatEther(locked),
        available: ethers.utils.formatEther(available),
      },
      locks,
      summary: {
        lockCount: lockCount.toNumber(),
        expiredLocks: locks.filter((l) => l.expired).length,
        nextUnlock: locks
          .filter((l) => !l.expired)
          .sort((a, b) => a.releaseTime - b.releaseTime)[0],
      },
    };
  }

  // Transfer with validation
  async transfer(to, amount, options = {}) {
    try {
      const amountWei = ethers.utils.parseEther(amount.toString());

      // Validation
      await this.validateTransfer(to, amountWei);

      // Estimate gas
      const gasEstimate = await this.contract.estimateGas.transfer(
        to,
        amountWei
      );

      const txOptions = {
        gasLimit: gasEstimate.mul(120).div(100), // 20% buffer
        ...options,
      };

      const tx = await this.contract.transfer(to, amountWei, txOptions);

      // Return transaction with enhanced info
      return {
        hash: tx.hash,
        to,
        amount,
        timestamp: Date.now(),
        status: "pending",
        wait: () => tx.wait(),
      };
    } catch (error) {
      throw this.formatError(error);
    }
  }

  // Claim expired locks
  async claimLocks() {
    try {
      // Check for expired locks first
      const portfolio = await this.getPortfolio();
      const expiredLocks = portfolio.locks.filter((l) => l.expired);

      if (expiredLocks.length === 0) {
        throw new Error("No expired locks to claim");
      }

      const tx = await this.contract.claim();

      return {
        hash: tx.hash,
        expiredCount: expiredLocks.length,
        totalAmount: expiredLocks.reduce(
          (sum, lock) => sum + parseFloat(lock.amount),
          0
        ),
        wait: () => tx.wait(),
      };
    } catch (error) {
      throw this.formatError(error);
    }
  }

  // Validation helpers
  async validateTransfer(to, amountWei) {
    if (!ethers.utils.isAddress(to)) {
      throw new Error("Invalid recipient address");
    }

    if (amountWei.lte(0)) {
      throw new Error("Amount must be greater than 0");
    }

    const available = await this.contract.getAvailableBalance(this.address);
    if (available.lt(amountWei)) {
      throw new Error(
        `Insufficient available balance. Available: ${ethers.utils.formatEther(
          available
        )} EDENA`
      );
    }

    // Check if account is frozen
    const isFrozen = await this.contract.frozenAccount(this.address);
    if (isFrozen) {
      throw new Error("Account is frozen");
    }
  }

  // Error formatting
  formatError(error) {
    if (error.code === "INSUFFICIENT_FUNDS") {
      return new Error("Insufficient MATIC for gas fees");
    } else if (
      error.message.includes("Transfer amount exceeds unlocked balance")
    ) {
      return new Error("Cannot transfer locked tokens");
    } else if (error.message.includes("Account is frozen")) {
      return new Error("Account is frozen");
    } else if (error.message.includes("Contract is paused")) {
      return new Error("Token contract is temporarily paused");
    } else {
      return error;
    }
  }

  // Event handling
  setupEventListeners() {
    // Personal transfer events
    const transferToFilter = this.contract.filters.Transfer(null, this.address);
    const transferFromFilter = this.contract.filters.Transfer(
      this.address,
      null
    );

    this.contract.on(transferToFilter, (from, to, value) => {
      this.onTokensReceived(from, value);
    });

    this.contract.on(transferFromFilter, (from, to, value) => {
      this.onTokensSent(to, value);
    });

    // Lock events
    const lockFilter = this.contract.filters.Lock(this.address);
    const unlockFilter = this.contract.filters.Unlock(this.address);

    this.contract.on(lockFilter, (holder, value, releaseTime, operator) => {
      this.onTokensLocked(value, releaseTime, operator);
    });

    this.contract.on(unlockFilter, (holder, value, operator) => {
      this.onTokensUnlocked(value, operator);
    });
  }

  // Event handlers (override in implementation)
  onTokensReceived(from, value) {
    console.log(
      `Received ${ethers.utils.formatEther(value)} EDENA from ${from}`
    );
  }

  onTokensSent(to, value) {
    console.log(`Sent ${ethers.utils.formatEther(value)} EDENA to ${to}`);
  }

  onTokensLocked(value, releaseTime, operator) {
    const releaseDate = new Date(releaseTime * 1000);
    console.log(
      `Locked ${ethers.utils.formatEther(
        value
      )} EDENA until ${releaseDate.toISOString()}`
    );
  }

  onTokensUnlocked(value, operator) {
    console.log(`Unlocked ${ethers.utils.formatEther(value)} EDENA`);
  }
}
```

## DeFi Protocol Integration

### Lending Protocol Integration

```javascript
class EDENALendingProtocol {
  constructor(provider, signer) {
    this.provider = provider;
    this.signer = signer;
    this.edenaToken = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      signer
    );
  }

  // Calculate collateral value
  async calculateCollateralValue(userAddress) {
    const availableBalance = await this.edenaToken.getAvailableBalance(
      userAddress
    );
    const lockedBalance = await this.edenaToken.getLockedBalance(userAddress);

    // Available tokens can be used as collateral immediately
    // Locked tokens have reduced collateral value
    const availableCollateral = availableBalance.mul(100); // 100% collateral ratio
    const lockedCollateral = lockedBalance.mul(50); // 50% collateral ratio for locked tokens

    return {
      availableCollateral: ethers.utils.formatEther(
        availableCollateral.div(100)
      ),
      lockedCollateral: ethers.utils.formatEther(lockedCollateral.div(100)),
      totalCollateral: ethers.utils.formatEther(
        availableCollateral.add(lockedCollateral).div(100)
      ),
    };
  }

  // Deposit as collateral
  async depositCollateral(amount) {
    try {
      // Validate user has enough available tokens
      const available = await this.edenaToken.getAvailableBalance(
        this.signer.address
      );
      const amountWei = ethers.utils.parseEther(amount.toString());

      if (available.lt(amountWei)) {
        throw new Error("Insufficient available balance for collateral");
      }

      // Transfer tokens to lending contract
      // Note: In real implementation, this would be a more complex interaction
      const tx = await this.edenaToken.transfer(
        LENDING_CONTRACT_ADDRESS,
        amountWei
      );

      return tx;
    } catch (error) {
      throw new Error(`Collateral deposit failed: ${error.message}`);
    }
  }

  // Calculate borrowing power
  async getBorrowingPower(userAddress) {
    const collateral = await this.calculateCollateralValue(userAddress);
    const borrowingRatio = 0.75; // 75% loan-to-value ratio

    return {
      maxBorrow: parseFloat(collateral.totalCollateral) * borrowingRatio,
      availableForBorrow:
        parseFloat(collateral.availableCollateral) * borrowingRatio,
      lockedAdjustment:
        parseFloat(collateral.lockedCollateral) * borrowingRatio,
    };
  }
}
```

### Staking Protocol Integration

```javascript
class EDENAStakingProtocol {
  constructor(provider, signer) {
    this.provider = provider;
    this.signer = signer;
    this.edenaToken = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      signer
    );
  }

  // Stake available tokens
  async stake(amount, lockPeriod) {
    try {
      const amountWei = ethers.utils.parseEther(amount.toString());

      // Validate staking amount
      const available = await this.edenaToken.getAvailableBalance(
        this.signer.address
      );
      if (available.lt(amountWei)) {
        throw new Error("Insufficient available balance for staking");
      }

      // Calculate staking rewards based on lock period
      const rewardMultiplier = this.calculateRewardMultiplier(lockPeriod);
      const estimatedRewards = amountWei.mul(rewardMultiplier).div(1000);

      // In a real implementation, this would interact with a staking contract
      // that has approval to lock tokens
      console.log(`Staking ${amount} EDENA for ${lockPeriod} days`);
      console.log(
        `Estimated rewards: ${ethers.utils.formatEther(estimatedRewards)} EDENA`
      );

      return {
        amount: amount,
        lockPeriod: lockPeriod,
        estimatedRewards: ethers.utils.formatEther(estimatedRewards),
        rewardMultiplier: rewardMultiplier / 10, // Convert to percentage
      };
    } catch (error) {
      throw new Error(`Staking failed: ${error.message}`);
    }
  }

  // Calculate reward multiplier based on lock period
  calculateRewardMultiplier(days) {
    if (days >= 365) return 120; // 12% APY for 1 year+
    if (days >= 180) return 100; // 10% APY for 6 months+
    if (days >= 90) return 80; // 8% APY for 3 months+
    if (days >= 30) return 60; // 6% APY for 1 month+
    return 40; // 4% APY for shorter periods
  }

  // Get staking history
  async getStakingHistory(userAddress) {
    // Query lock events for staking-related locks
    const lockFilter = this.edenaToken.filters.Lock(userAddress);
    const events = await this.edenaToken.queryFilter(lockFilter, -10000); // Last 10k blocks

    return events.map((event) => ({
      amount: ethers.utils.formatEther(event.args.value),
      lockTime: new Date(event.blockNumber * 1000), // Approximation
      releaseTime: new Date(event.args.releaseTime * 1000),
      operator: event.args.operator,
      transactionHash: event.transactionHash,
    }));
  }
}
```

## Exchange Integration

### Trading Pair Integration

```javascript
class EDENAExchangeIntegration {
  constructor(provider, signer) {
    this.provider = provider;
    this.signer = signer;
    this.edenaToken = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      signer
    );
  }

  // Get tradeable balance (excludes locked tokens)
  async getTradeableBalance(userAddress) {
    return await this.edenaToken.getAvailableBalance(userAddress);
  }

  // Validate trade order
  async validateTradeOrder(userAddress, sellAmount) {
    const availableBalance = await this.getTradeableBalance(userAddress);
    const sellAmountWei = ethers.utils.parseEther(sellAmount.toString());

    if (availableBalance.lt(sellAmountWei)) {
      throw new Error(
        "Insufficient tradeable balance. Some tokens may be locked."
      );
    }

    // Check account status
    const isFrozen = await this.edenaToken.frozenAccount(userAddress);
    if (isFrozen) {
      throw new Error("Account is frozen and cannot trade");
    }

    return true;
  }

  // Get market metrics
  async getMarketMetrics() {
    const [totalSupply, lockSummary] = await Promise.all([
      this.edenaToken.totalSupply(),
      this.edenaToken.getLockSummary(),
    ]);

    const [totalLockedAddresses, totalLockedAmount, totalLockCount] =
      lockSummary;

    const circulatingSupply = totalSupply.sub(totalLockedAmount);
    const lockRatio = totalLockedAmount.mul(100).div(totalSupply);

    return {
      totalSupply: ethers.utils.formatEther(totalSupply),
      circulatingSupply: ethers.utils.formatEther(circulatingSupply),
      totalLocked: ethers.utils.formatEther(totalLockedAmount),
      lockRatio: lockRatio.toNumber(),
      lockedAddresses: totalLockedAddresses.toNumber(),
      lockCount: totalLockCount.toNumber(),
    };
  }

  // Monitor liquidity events
  setupLiquidityMonitoring() {
    // Monitor unlock events that increase circulating supply
    this.edenaToken.on("Unlock", (holder, value, operator) => {
      const amount = ethers.utils.formatEther(value);
      console.log(`Liquidity increased: ${amount} EDENA unlocked`);

      // Notify trading systems of liquidity change
      this.onLiquidityChange("increase", amount, holder);
    });

    // Monitor lock events that decrease circulating supply
    this.edenaToken.on("Lock", (holder, value, releaseTime, operator) => {
      const amount = ethers.utils.formatEther(value);
      console.log(`Liquidity decreased: ${amount} EDENA locked`);

      // Notify trading systems of liquidity change
      this.onLiquidityChange("decrease", amount, holder);
    });
  }

  onLiquidityChange(direction, amount, holder) {
    // Override in implementation to handle liquidity changes
    console.log(`Liquidity ${direction}: ${amount} EDENA (${holder})`);
  }
}
```

## Governance Integration

### DAO Integration

```javascript
class EDENAGovernanceIntegration {
  constructor(provider, signer) {
    this.provider = provider;
    this.signer = signer;
    this.edenaToken = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      signer
    );
  }

  // Create proposal snapshot
  async createProposalSnapshot(proposalId) {
    try {
      // Only owner can create snapshots
      const tx = await this.edenaToken.snapshot();
      const receipt = await tx.wait();

      // Extract snapshot ID from event
      const snapshotEvent = receipt.events.find(
        (e) => e.event === "SnapshotCreated"
      );
      const snapshotId = snapshotEvent.args.snapshotId;

      console.log(`Created snapshot ${snapshotId} for proposal ${proposalId}`);

      return {
        proposalId,
        snapshotId: snapshotId.toNumber(),
        blockNumber: receipt.blockNumber,
        timestamp: Date.now(),
      };
    } catch (error) {
      throw new Error(`Snapshot creation failed: ${error.message}`);
    }
  }

  // Calculate voting power
  async getVotingPower(voterAddress, snapshotId) {
    const balance = await this.edenaToken.balanceOfAt(voterAddress, snapshotId);
    return ethers.utils.formatEther(balance);
  }

  // Get all eligible voters
  async getEligibleVoters(snapshotId, minimumBalance = "100") {
    const addresses = await this.edenaToken.getSnapshotAddresses(snapshotId);
    const minimumWei = ethers.utils.parseEther(minimumBalance);

    const eligibleVoters = [];

    for (const address of addresses) {
      const balance = await this.edenaToken.balanceOfAt(address, snapshotId);
      if (balance.gte(minimumWei)) {
        eligibleVoters.push({
          address,
          votingPower: ethers.utils.formatEther(balance),
        });
      }
    }

    // Sort by voting power
    eligibleVoters.sort(
      (a, b) => parseFloat(b.votingPower) - parseFloat(a.votingPower)
    );

    return eligibleVoters;
  }

  // Proposal management
  async createProposal(title, description, options, votingPeriod = 7) {
    // Create snapshot for voting
    const snapshot = await this.createProposalSnapshot();

    const proposal = {
      id: Date.now(), // In real implementation, use proper ID generation
      title,
      description,
      options,
      snapshotId: snapshot.snapshotId,
      startTime: Date.now(),
      endTime: Date.now() + votingPeriod * 24 * 60 * 60 * 1000,
      status: "active",
      votes: {},
      results: {},
    };

    return proposal;
  }

  // Vote validation
  async validateVote(voterAddress, proposalId, snapshotId) {
    const votingPower = await this.getVotingPower(voterAddress, snapshotId);

    if (parseFloat(votingPower) === 0) {
      throw new Error("No voting power at snapshot time");
    }

    return {
      canVote: true,
      votingPower: votingPower,
    };
  }
}
```

## Analytics Integration

### Data Collection and Analysis

```javascript
class EDENAAnalytics {
  constructor(provider) {
    this.provider = provider;
    this.edenaToken = new ethers.Contract(
      CONTRACT_CONFIG.address,
      CONTRACT_CONFIG.abi,
      provider
    );
  }

  // Comprehensive token metrics
  async getTokenMetrics() {
    const [totalSupply, lockSummary, registeredCount] = await Promise.all([
      this.edenaToken.totalSupply(),
      this.edenaToken.getLockSummary(),
      this.edenaToken.getRegisteredAddressCount(),
    ]);

    const [totalLockedAddresses, totalLockedAmount, totalLockCount] =
      lockSummary;

    return {
      supply: {
        total: ethers.utils.formatEther(totalSupply),
        locked: ethers.utils.formatEther(totalLockedAmount),
        circulating: ethers.utils.formatEther(
          totalSupply.sub(totalLockedAmount)
        ),
      },
      holders: {
        registered: registeredCount.toNumber(),
        withLocks: totalLockedAddresses.toNumber(),
        lockRatio: totalLockedAddresses
          .mul(100)
          .div(registeredCount)
          .toNumber(),
      },
      locks: {
        total: totalLockCount.toNumber(),
        averagePerHolder: totalLockCount.div(totalLockedAddresses).toNumber(),
      },
    };
  }

  // Historical analysis
  async analyzeHistoricalData(fromBlock, toBlock) {
    const [transferEvents, lockEvents, unlockEvents] = await Promise.all([
      this.edenaToken.queryFilter(
        this.edenaToken.filters.Transfer(),
        fromBlock,
        toBlock
      ),
      this.edenaToken.queryFilter(
        this.edenaToken.filters.Lock(),
        fromBlock,
        toBlock
      ),
      this.edenaToken.queryFilter(
        this.edenaToken.filters.Unlock(),
        fromBlock,
        toBlock
      ),
    ]);

    return {
      transfers: {
        count: transferEvents.length,
        volume: this.calculateVolume(transferEvents),
      },
      locks: {
        count: lockEvents.length,
        volume: this.calculateVolume(lockEvents),
      },
      unlocks: {
        count: unlockEvents.length,
        volume: this.calculateVolume(unlockEvents),
      },
    };
  }

  calculateVolume(events) {
    return events.reduce((total, event) => {
      return total.add(
        event.args.value || event.args.amount || ethers.BigNumber.from(0)
      );
    }, ethers.BigNumber.from(0));
  }

  // Real-time monitoring
  setupRealTimeAnalytics() {
    // Track all major events
    this.edenaToken.on("Transfer", this.onTransfer.bind(this));
    this.edenaToken.on("Lock", this.onLock.bind(this));
    this.edenaToken.on("Unlock", this.onUnlock.bind(this));
    this.edenaToken.on("SnapshotCreated", this.onSnapshot.bind(this));
  }

  onTransfer(from, to, value) {
    // Record transfer for analytics
    this.recordEvent("transfer", {
      from,
      to,
      value: ethers.utils.formatEther(value),
      timestamp: Date.now(),
    });
  }

  onLock(holder, value, releaseTime, operator) {
    this.recordEvent("lock", {
      holder,
      value: ethers.utils.formatEther(value),
      releaseTime: releaseTime.toNumber(),
      operator,
      timestamp: Date.now(),
    });
  }

  onUnlock(holder, value, operator) {
    this.recordEvent("unlock", {
      holder,
      value: ethers.utils.formatEther(value),
      operator,
      timestamp: Date.now(),
    });
  }

  onSnapshot(snapshotId, totalAddresses, totalSupply) {
    this.recordEvent("snapshot", {
      snapshotId: snapshotId.toNumber(),
      totalAddresses: totalAddresses.toNumber(),
      totalSupply: ethers.utils.formatEther(totalSupply),
      timestamp: Date.now(),
    });
  }

  recordEvent(type, data) {
    // Override in implementation to store events
    console.log(`Analytics Event [${type}]:`, data);
  }
}
```

## Error Handling and Best Practices

### Comprehensive Error Handling

```javascript
class EDENAErrorHandler {
  static handleContractError(error) {
    // Common contract errors
    const errorMappings = {
      "Transfer amount exceeds unlocked balance":
        "Cannot transfer locked tokens",
      "Must call by Owner or Approved Contract": "Insufficient permissions",
      "Account is frozen": "Account is frozen and cannot perform operations",
      "Contract is paused": "Token contract is temporarily paused",
      "Cannot lock zero address": "Invalid address for lock operation",
      "Lock amount must be greater than 0": "Lock amount must be positive",
      "Release time must be in the future": "Invalid release time",
      "Lock period not expired": "Tokens are still locked",
      "Insufficient unlocked balance for lock":
        "Not enough available tokens to lock",
    };

    // Check for known error patterns
    for (const [pattern, message] of Object.entries(errorMappings)) {
      if (error.message.includes(pattern)) {
        return new Error(message);
      }
    }

    // Handle common web3 errors
    if (error.code === "INSUFFICIENT_FUNDS") {
      return new Error("Insufficient MATIC for gas fees");
    }

    if (error.code === "UNPREDICTABLE_GAS_LIMIT") {
      return new Error("Transaction may fail - please check parameters");
    }

    if (error.code === "NETWORK_ERROR") {
      return new Error("Network connection error - please try again");
    }

    // Return original error if not recognized
    return error;
  }

  static async validateTransaction(contract, method, params) {
    try {
      // Estimate gas to validate transaction
      await contract.estimateGas[method](...params);
      return true;
    } catch (error) {
      throw this.handleContractError(error);
    }
  }
}
```

## Testing Integration

### Unit Tests Example

```javascript
// Example using Jest and ethers.js
describe("EDENA Token Integration", () => {
  let edenaToken;
  let wallet;
  let provider;

  beforeEach(async () => {
    // Setup test environment
    provider = new ethers.providers.JsonRpcProvider("http://localhost:8545");
    wallet = new ethers.Wallet("PRIVATE_KEY", provider);
    edenaToken = new ethers.Contract(CONTRACT_ADDRESS, CONTRACT_ABI, wallet);
  });

  test("should get correct balance information", async () => {
    const address = wallet.address;

    const [total, locked, available] = await Promise.all([
      edenaToken.balanceOf(address),
      edenaToken.getLockedBalance(address),
      edenaToken.getAvailableBalance(address),
    ]);

    expect(total.gte(locked.add(available))).toBe(true);
    expect(locked.gte(0)).toBe(true);
    expect(available.gte(0)).toBe(true);
  });

  test("should transfer only available tokens", async () => {
    const recipient = "0x742d35Cc6634C0532925a3b8D238AA3a1A21b5d1";
    const amount = ethers.utils.parseEther("10");

    const availableBefore = await edenaToken.getAvailableBalance(
      wallet.address
    );

    if (availableBefore.gte(amount)) {
      const tx = await edenaToken.transfer(recipient, amount);
      await tx.wait();

      const availableAfter = await edenaToken.getAvailableBalance(
        wallet.address
      );
      expect(availableAfter).toBe(availableBefore.sub(amount));
    }
  });
});
```

## Next Steps

- [API Reference](../api/overview.md) - Complete function documentation
- [Lock Management API](../api/lock-management.md) - Detailed lock operations
- [Account Management API](../api/account.md) - User and permission management
