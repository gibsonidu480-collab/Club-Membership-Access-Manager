# 🏛️ Club Membership Access Manager

A comprehensive smart contract for managing exclusive club memberships on the Stacks blockchain. This contract enables clubs to manage member registration, tiered access levels, and automated membership renewals.

## ✨ Features

- 🎫 **Multi-tier Membership System** - Basic, Premium, and VIP membership levels
- 💳 **Automated Payment Processing** - Secure STX payments for memberships
- ⏰ **Time-based Access Control** - Block-height based membership expiration
- 📊 **Access Tracking** - Complete audit trail of member activities
- 🔧 **Admin Controls** - Member activation/deactivation capabilities
- 💰 **Treasury Management** - Secure fund collection and withdrawal

## 🎭 Membership Tiers

| Tier | Price (STX) | Duration (Blocks) | Max Guests | Priority Booking |
|------|-------------|-------------------|------------|------------------|
| Basic | 1.0 | 2,100 (~2 weeks) | 1 | ❌ |
| Premium | 2.5 | 4,200 (~4 weeks) | 3 | ✅ |
| VIP | 5.0 | 8,400 (~8 weeks) | 5 | ✅ |

## 🚀 Quick Start

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- Stacks wallet with STX tokens

### Installation

```bash
git clone <repository-url>
cd Club-Membership-Access-Manager
clarinet check
```

### Testing

```bash
npm install
npm test
```

## 📖 Contract Functions

### 🔓 Public Functions

#### Member Registration
```clarity
(register-member (tier uint))
```
Register as a new club member with specified tier (1=Basic, 2=Premium, 3=VIP).

#### Membership Management
```clarity
(renew-membership (duration-blocks uint))
(upgrade-membership (new-tier uint))
(access-club (access-type (string-ascii 20)))
```

#### Admin Functions
```clarity
(initialize-tiers)
(deactivate-member (member-id uint))
(reactivate-member (member-id uint))
(withdraw-treasury (amount uint))
```

### 👁️ Read-Only Functions

```clarity
(get-member-info (member-id uint))
(get-member-by-wallet (wallet principal))
(is-member-active (wallet principal))
(get-member-tier (wallet principal))
(get-membership-expiry (wallet principal))
(get-tier-info (tier uint))
(get-club-stats)
(get-tier-pricing)
```

## 💻 Usage Examples

### Register a Premium Membership

```clarity
;; Register as Premium member (tier 2)
(contract-call? .club-membership-access-manager register-member u2)
```

### Check Member Status

```clarity
;; Check if a wallet is an active member
(contract-call? .club-membership-access-manager is-member-active 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)
```

### Access Club Facilities

```clarity
;; Log access to gym facility
(contract-call? .club-membership-access-manager access-club "gym")
```

### Upgrade Membership

```clarity
;; Upgrade from Basic to VIP
(contract-call? .club-membership-access-manager upgrade-membership u3)
```

## 🏗️ Contract Architecture

### Data Structures

- **Members Map**: Stores member information including tier, expiry, and activity
- **Member by Wallet**: Quick lookup for wallet-to-member-ID mapping
- **Access Logs**: Complete audit trail of all club access events
- **Tier Benefits**: Configuration for each membership tier

### Error Codes

| Code | Description |
|------|-------------|
| u100 | Owner only operation |
| u101 | Member not found |
| u102 | Member already exists |
| u103 | Unauthorized access |
| u104 | Invalid tier |
| u105 | Membership expired |
| u106 | Insufficient payment |
| u107 | Invalid duration |

## 🛡️ Security Features

- ✅ Owner-only administrative functions
- ✅ Input validation for all parameters
- ✅ Payment verification before membership activation
- ✅ Block-height based expiration system
- ✅ Access control for expired memberships

## 🎯 Use Cases

- 🏋️ **Fitness Centers** - Manage gym memberships and facility access
- 🍽️ **Private Clubs** - Exclusive dining and social club access
- 🎪 **Event Venues** - Tiered access to events and facilities
- 🏢 **Co-working Spaces** - Flexible membership management
- 🎭 **Entertainment Venues** - VIP and general access control

## 📊 Club Analytics

The contract provides comprehensive analytics through read-only functions:

- Total member count
- Club treasury balance
- Individual member access patterns
- Tier distribution statistics

## 🔧 Configuration

Contract constants can be modified for different club needs:

```clarity
(define-constant basic-price u100000)    ;; 1.0 STX
(define-constant premium-price u250000)  ;; 2.5 STX  
(define-constant vip-price u500000)      ;; 5.0 STX
```

## 📝 Development

### Project Structure

```
├── contracts/
│   └── Club-Membership-Access-Manager.clar
├── tests/
│   └── Club-Membership-Access-Manager.test.ts
├── settings/
│   └── Devnet.toml
└── Clarinet.toml
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests for new functionality
5. Run `clarinet check` to verify
6. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🤝 Support

- 📧 Email: support@clubmanager.dev
- 💬 Discord: [Join our server](https://discord.gg/clubmanager)
- 📖 Documentation: [Full API docs](https://docs.clubmanager.dev)

---

*Built with ❤️ for the Stacks ecosystem*
