# 🏠 Refugee Donations Platform

A transparent blockchain-based donation platform built on Stacks that enables direct cryptocurrency aid to verified displaced individuals and refugee support campaigns.

## 🌟 Features

- 🔐 **Verified Refugee Registration**: Only contract owner can register and verify refugees
- 💰 **Direct Donations**: Send STX directly to verified refugee wallets
- 📊 **Campaign Support**: Create and fund community campaigns for refugee aid
- 🔍 **Full Transparency**: All donations are recorded on-chain
- 📈 **Real-time Tracking**: Monitor donation amounts and campaign progress

## 🚀 Getting Started

### Prerequisites

- Clarinet CLI installed
- Stacks wallet for testing

### Installation

```bash
git clone <repository-url>
cd refugee-donations
clarinet check
```

## 📋 Contract Functions

### 👥 Refugee Management

#### Register Refugee (Owner Only)
```clarity
(contract-call? .refugee-donations register-refugee 'ST1REFUGEE... "John Doe" "Ukraine" "Family displaced from conflict")
```

#### Verify Refugee (Owner Only)
```clarity
(contract-call? .refugee-donations verify-refugee u1)
```

### 💸 Donations

#### Donate to Verified Refugee
```clarity
(contract-call? .refugee-donations donate-to-refugee u1 u1000000)
```

#### Create Campaign
```clarity
(contract-call? .refugee-donations create-campaign "Emergency Shelter Fund" "Providing temporary housing for displaced families" u10000000)
```

#### Donate to Campaign
```clarity
(contract-call? .refugee-donations donate-to-campaign u1 u500000)
```

### 📖 Read Functions

#### Get Refugee Information
```clarity
(contract-call? .refugee-donations get-refugee u1)
```

#### Get Campaign Details
```clarity
(contract-call? .refugee-donations get-campaign u1)
```

#### Check Donation History
```clarity
(contract-call? .refugee-donations get-donation 'ST1DONOR... u1)
```

#### Get Total Platform Donations
```clarity
(contract-call? .refugee-donations get-total-donations)
```

## 🔧 Testing

Run the test suite:

```bash
clarinet test
```

Deploy to local testnet:

```bash
clarinet integrate
```

## 🏗️ Architecture

### Data Structures

- **Refugees**: Verified individuals who can receive donations
- **Campaigns**: Community-driven fundraising initiatives  
- **Donations**: Individual contribution records
- **Wallet Lookup**: Quick refugee identification by wallet address

### Security Features

- ✅ Owner-only refugee registration and verification
- ✅ Amount validation for all transactions
- ✅ Verified status checks before donations
- ✅ Campaign status management
- ✅ Direct wallet-to-wallet transfers

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

For support and questions, please open an issue in the GitHub repository.

---

*Built with ❤️ for humanitarian aid transparency*
```

**Git Commit Message:**
```
feat: implement MVP refugee donations platform with verified recipients and transparent tracking
```

**GitHub Pull Request Title:**
```
🏠 Add Refugee Donations Platform MVP - Direct crypto aid with verification system
```

**GitHub Pull Request Description:**
```
## 🚀 What's Added

This PR introduces a complete MVP for a transparent refugee donations platform built on Stacks blockchain.

### ✨ Key Features
- **Verified Refugee System**: Owner-controlled registration and verification process
- **Direct Donations**: STX transfers directly to refugee wallets
- **Campaign Support**: Community-driven fundraising campaigns
- **Full Transparency**: All donations tracked on-chain
- **Security Controls**: Proper authorization and validation checks

### 📁 Files Added
- `contracts/refugee-donations.clar` - Main smart contract (150+ lines)
- `README.md` - Complete documentation with usage examples

### 🔧 Technical Highlights
- Implements secure donation tracking with dual mapping system
- Provides both individual and campaign-based donation flows  
- Includes comprehensive read-only functions for transparency
- Features proper error handling and access controls

Ready for testing and deployment to help provide transparent aid to displaced individuals worldwide. 🌍
