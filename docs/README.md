# EDENA Token V2 Documentation

Welcome to the comprehensive documentation for EDENA Token V2, an advanced ERC20 token with sophisticated lock-up mechanisms and UUPS upgradeability.

## What is EDENA Token V2?

EDENA Token V2 is a next-generation ERC20 token that implements:

- **Advanced Lock System**: Time-based token locks with automated release
- **UUPS Upgradeability**: Future-proof contract architecture
- **Gas Optimization**: Efficient O(1) lock balance queries
- **Enterprise Security**: Reentrancy protection and comprehensive access control
- **Snapshot Governance**: Historical balance tracking for governance

## Key Features

### Sophisticated Lock Management

- Multiple simultaneous locks per address
- Automatic and manual unlock mechanisms
- Real-time lock status monitoring
- Transferable vs locked balance separation

### Upgradeable Architecture

- UUPS (Universal Upgradeable Proxy Standard) pattern
- Owner-controlled upgrade authorization
- Storage gap for future extensions

### Gas Optimized

- O(1) locked balance queries via `lockedAmount` mapping
- Efficient array management for lock removal
- Batch processing for multiple operations

### Enterprise Security

- Multi-layer access control system
- Reentrancy attack prevention
- Emergency pause functionality
- Account freezing capabilities

## Quick Navigation

### For Developers

- [API Reference](api/overview.md) - Complete function documentation
- [Integration Guide](guides/integration.md) - How to integrate with your dApp

### For Users

- [Quick Start](guides/quick-start.md) - Get started quickly

## Token Information

| Property             | Value                   |
| -------------------- | ----------------------- |
| **Token Name**       | EDENA Token V2          |
| **Token Symbol**     | EDENA                   |
| **Total Supply**     | 1,000,000,000 EDENA     |
| **Decimals**         | 18                      |
| **Contract Name**    | LockToken               |
| **Network**          | Polygon                 |
| **Contract Address** | `0x...` (To be updated) |

## Technical Specifications

| Property             | Value            |
| -------------------- | ---------------- |
| **Solidity Version** | 0.8.22           |
| **Standard**         | ERC20Upgradeable |
| **Upgrade Pattern**  | UUPS             |
| **License**          | MIT              |

## Getting Started

1. **Read the [API Overview](api/overview.md)** to understand the contract structure
2. **Follow the [Quick Start Guide](guides/quick-start.md)** for setup instructions
3. **Check the [Integration Guide](guides/integration.md)** for implementation patterns

## Support

- **GitHub Repository**: [View source code and report issues](https://github.com/your-org/edena-token)
- **Documentation**: This GitBook documentation
- **Community**: Join our community channels for support and discussions

---

{% hint style="info" %}
This documentation covers EDENA Token V2. For the previous version, see the legacy documentation.
{% endhint %}

{% hint style="warning" %}
Always perform thorough testing on testnets before mainnet deployment.
{% endhint %}
