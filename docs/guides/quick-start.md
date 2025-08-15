# Quick Start Guide

Get up and running with EDENA Token V2 in minutes. This guide covers the essential steps to interact with the contract.

## Prerequisites

- **Node.js** (v16 or higher)
- **Web3 library** (ethers.js or web3.js)
- **Polygon network access** (RPC endpoint)
- **Wallet** with MATIC for gas fees

## Installation

### Using ethers.js (Recommended)

```bash
npm install ethers
```

### Using web3.js

```bash
npm install web3
```

## Contract Connection

### Basic Setup

```javascript
import { ethers } from "ethers";

// Connect to Polygon network
const provider = new ethers.providers.JsonRpcProvider(
  "https://polygon-rpc.com"
);

const CONTRACT_ADDRESS = "0x6658c12Ee0A2D3127E006d168964f8FA17ab435E";

// Contract ABI (simplified for quick start)
const LOCK_TOKEN_ABI = [
  // ERC20 functions
  "function balanceOf(address owner) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function approve(address spender, uint256 amount) returns (bool)",

  // Lock management
  "function getLockedBalance(address owner) view returns (uint256)",
  "function getAvailableBalance(address owner) view returns (uint256)",
  "function claim() returns (uint256)",
  "function getLockDetails(address holder) view returns (uint256, uint256, uint256[], uint256[])",

  // Snapshot
  "function balanceOfAt(address account, uint256 snapshotId) view returns (uint256)",

  // Events
  "event Lock(address indexed holder, uint256 value, uint256 releaseTime, address indexed operator)",
  "event Unlock(address indexed holder, uint256 value, address indexed operator)",
  "event Transfer(address indexed from, address indexed to, uint256 value)",
];

// Create contract instance
const lockToken = new ethers.Contract(
  CONTRACT_ADDRESS,
  LOCK_TOKEN_ABI,
  provider
);
```

## Basic Operations

### 1. Check Token Balance

```javascript
async function checkBalance(address) {
  try {
    // Total balance (transferable + locked)
    const totalBalance = await lockToken.balanceOf(address);

    // Locked balance
    const lockedBalance = await lockToken.getLockedBalance(address);

    // Available for transfer
    const availableBalance = await lockToken.getAvailableBalance(address);

    console.log("Balances for", address);
    console.log("Total:", ethers.utils.formatEther(totalBalance), "EDENA");
    console.log("Locked:", ethers.utils.formatEther(lockedBalance), "EDENA");
    console.log(
      "Available:",
      ethers.utils.formatEther(availableBalance),
      "EDENA"
    );

    return {
      total: totalBalance,
      locked: lockedBalance,
      available: availableBalance,
    };
  } catch (error) {
    console.error("Error checking balance:", error);
  }
}

// Usage - Replace with actual address
await checkBalance("0x1234567890123456789012345678901234567890");
```

### 2. Transfer Tokens

```javascript
async function transferTokens(signer, to, amount) {
  try {
    // Connect contract with signer
    const lockTokenWithSigner = lockToken.connect(signer);

    // Convert amount to wei
    const amountWei = ethers.utils.parseEther(amount.toString());

    // Check available balance first
    const available = await lockTokenWithSigner.getAvailableBalance(
      signer.address
    );

    if (available.lt(amountWei)) {
      throw new Error("Insufficient available balance");
    }

    // Send transaction
    const tx = await lockTokenWithSigner.transfer(to, amountWei);
    console.log("Transaction hash:", tx.hash);

    // Wait for confirmation
    const receipt = await tx.wait();
    console.log("Transfer confirmed in block:", receipt.blockNumber);

    return receipt;
  } catch (error) {
    console.error("Transfer failed:", error);
  }
}

// Usage
const signer = new ethers.Wallet("PRIVATE_KEY", provider);
await transferTokens(signer, "0x...", 100); // Transfer 100 EDENA
```

### 3. Claim Expired Locks

```javascript
async function claimExpiredLocks(signer) {
  try {
    const lockTokenWithSigner = lockToken.connect(signer);

    // Check lock details first
    const [lockCount, totalLocked, releaseTimes, amounts] =
      await lockTokenWithSigner.getLockDetails(signer.address);

    console.log(
      `Found ${lockCount} locks totaling ${ethers.utils.formatEther(
        totalLocked
      )} EDENA`
    );

    // Check for expired locks
    const now = Math.floor(Date.now() / 1000);
    let expiredCount = 0;
    let expiredAmount = ethers.BigNumber.from(0);

    for (let i = 0; i < lockCount; i++) {
      if (releaseTimes[i].lte(now)) {
        expiredCount++;
        expiredAmount = expiredAmount.add(amounts[i]);
      }
    }

    if (expiredCount === 0) {
      console.log("No expired locks to claim");
      return;
    }

    console.log(
      `${expiredCount} locks ready to claim: ${ethers.utils.formatEther(
        expiredAmount
      )} EDENA`
    );

    // Claim expired locks
    const tx = await lockTokenWithSigner.claim();
    console.log("Claim transaction:", tx.hash);

    const receipt = await tx.wait();
    console.log("Claim confirmed:", receipt.blockNumber);

    // Parse unlock events
    const unlockEvents =
      receipt.events?.filter((e) => e.event === "Unlock") || [];
    console.log(`Successfully unlocked ${unlockEvents.length} locks`);

    return receipt;
  } catch (error) {
    console.error("Claim failed:", error);
  }
}

// Usage
await claimExpiredLocks(signer);
```

### 4. View Lock Details

```javascript
async function viewLockDetails(address) {
  try {
    const [lockCount, totalLocked, releaseTimes, amounts] =
      await lockToken.getLockDetails(address);

    console.log(`Lock Details for ${address}`);
    console.log(`Total Locks: ${lockCount}`);
    console.log(`Total Locked: ${ethers.utils.formatEther(totalLocked)} EDENA`);

    if (lockCount.gt(0)) {
      console.log("\nIndividual Locks:");
      for (let i = 0; i < lockCount; i++) {
        const releaseDate = new Date(releaseTimes[i] * 1000);
        const amount = ethers.utils.formatEther(amounts[i]);
        const isExpired = Date.now() > releaseDate.getTime();

        console.log(
          `Lock ${i + 1}: ${amount} EDENA until ${releaseDate.toISOString()} ${
            isExpired ? "(EXPIRED)" : ""
          }`
        );
      }
    }

    return {
      lockCount: lockCount.toNumber(),
      totalLocked: ethers.utils.formatEther(totalLocked),
      locks: releaseTimes.map((time, i) => ({
        amount: ethers.utils.formatEther(amounts[i]),
        releaseTime: time.toNumber(),
        releaseDate: new Date(time * 1000),
        expired: Date.now() / 1000 > time.toNumber(),
      })),
    };
  } catch (error) {
    console.error("Error viewing lock details:", error);
  }
}

// Usage - Replace with actual address
await viewLockDetails("0x1234567890123456789012345678901234567890");
```

## Event Monitoring

### Listen for Real-time Events

```javascript
function setupEventListeners() {
  // Listen for new locks
  lockToken.on("Lock", (holder, value, releaseTime, operator) => {
    console.log("New Lock Created:");
    console.log("  Holder:", holder);
    console.log("  Amount:", ethers.utils.formatEther(value), "EDENA");
    console.log("  Release Time:", new Date(releaseTime * 1000).toISOString());
    console.log("  Operator:", operator);
  });

  // Listen for unlocks
  lockToken.on("Unlock", (holder, value, operator) => {
    console.log("Tokens Unlocked:");
    console.log("  Holder:", holder);
    console.log("  Amount:", ethers.utils.formatEther(value), "EDENA");
    console.log("  Operator:", operator);
  });

  // Listen for transfers
  lockToken.on("Transfer", (from, to, value) => {
    console.log("Transfer:");
    console.log("  From:", from);
    console.log("  To:", to);
    console.log("  Amount:", ethers.utils.formatEther(value), "EDENA");
  });
}

// Start listening
setupEventListeners();
```

### Query Historical Events

```javascript
async function getRecentLocks(address, blocks = 10000) {
  try {
    const currentBlock = await provider.getBlockNumber();
    const fromBlock = currentBlock - blocks;

    // Filter for lock events
    const filter = lockToken.filters.Lock(address);
    const events = await lockToken.queryFilter(filter, fromBlock);

    console.log(`Found ${events.length} lock events in last ${blocks} blocks`);

    events.forEach((event, i) => {
      const { holder, value, releaseTime, operator } = event.args;
      console.log(`Lock ${i + 1}:`);
      console.log("  Amount:", ethers.utils.formatEther(value), "EDENA");
      console.log("  Release:", new Date(releaseTime * 1000).toISOString());
      console.log("  Block:", event.blockNumber);
    });

    return events;
  } catch (error) {
    console.error("Error querying events:", error);
  }
}

// Usage - Replace with actual address
await getRecentLocks("0x1234567890123456789012345678901234567890");
```

## Common Use Cases

### 1. Wallet Integration

```javascript
class EDENAWallet {
  constructor(provider, signer) {
    this.provider = provider;
    this.signer = signer;
    this.contract = new ethers.Contract(
      CONTRACT_ADDRESS,
      LOCK_TOKEN_ABI,
      signer
    );
  }

  async getBalances() {
    const address = this.signer.address;
    return {
      total: await this.contract.balanceOf(address),
      locked: await this.contract.getLockedBalance(address),
      available: await this.contract.getAvailableBalance(address),
    };
  }

  async transfer(to, amount) {
    const amountWei = ethers.utils.parseEther(amount.toString());
    return await this.contract.transfer(to, amountWei);
  }

  async claimLocks() {
    return await this.contract.claim();
  }
}
```

### 2. Dashboard Component

```javascript
class EDENADashboard {
  constructor(provider, userAddress) {
    this.provider = provider;
    this.userAddress = userAddress;
    this.contract = new ethers.Contract(
      CONTRACT_ADDRESS,
      LOCK_TOKEN_ABI,
      provider
    );
  }

  async loadDashboard() {
    const balances = await this.getBalances();
    const locks = await this.getLockDetails();

    return {
      balances,
      locks,
      canClaim: locks.some((lock) => lock.expired),
    };
  }

  async getBalances() {
    const total = await this.contract.balanceOf(this.userAddress);
    const locked = await this.contract.getLockedBalance(this.userAddress);
    const available = await this.contract.getAvailableBalance(this.userAddress);

    return {
      total: ethers.utils.formatEther(total),
      locked: ethers.utils.formatEther(locked),
      available: ethers.utils.formatEther(available),
    };
  }

  async getLockDetails() {
    const [, , releaseTimes, amounts] = await this.contract.getLockDetails(
      this.userAddress
    );
    const now = Date.now() / 1000;

    return releaseTimes.map((time, i) => ({
      amount: ethers.utils.formatEther(amounts[i]),
      releaseTime: time.toNumber(),
      releaseDate: new Date(time * 1000),
      expired: now > time.toNumber(),
    }));
  }
}
```

## Error Handling

### Common Errors and Solutions

```javascript
async function safeTransfer(signer, to, amount) {
  try {
    const contract = lockToken.connect(signer);
    const amountWei = ethers.utils.parseEther(amount.toString());

    // Pre-flight checks
    const available = await contract.getAvailableBalance(signer.address);
    if (available.lt(amountWei)) {
      throw new Error(
        `Insufficient available balance. Available: ${ethers.utils.formatEther(
          available
        )} EDENA`
      );
    }

    // Estimate gas
    const gasEstimate = await contract.estimateGas.transfer(to, amountWei);

    // Send with gas limit
    const tx = await contract.transfer(to, amountWei, {
      gasLimit: gasEstimate.mul(120).div(100), // 20% buffer
    });

    return await tx.wait();
  } catch (error) {
    if (error.code === "INSUFFICIENT_FUNDS") {
      throw new Error("Insufficient MATIC for gas fees");
    } else if (
      error.message.includes("Transfer amount exceeds unlocked balance")
    ) {
      throw new Error("Cannot transfer locked tokens");
    } else if (error.message.includes("Account is frozen")) {
      throw new Error("Account is frozen and cannot transfer tokens");
    } else {
      throw new Error(`Transfer failed: ${error.message}`);
    }
  }
}
```

## Next Steps

### Advanced Features

- [Lock Management API](../api/lock-management.md) - Detailed lock operations
- [Snapshot API](../api/snapshot.md) - Historical balance tracking
- [Account Management](../api/account.md) - User management features

### Integration Guides

- [Integration Guide](integration.md) - Full system integration

### Development

- Coming soon: Additional guides and examples

## Support

- **Documentation**: Complete API reference in this GitBook
- **Issues**: Report issues on GitHub
- **Community**: Join our Discord/Telegram channels
