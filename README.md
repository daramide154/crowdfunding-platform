# Crowdfunding Platform

A decentralized crowdfunding platform that enables creators to launch campaigns and receive funding in STX tokens. Features milestone-based funding release, contributor governance, automatic refunds for failed campaigns, and creator reputation scoring based on project success rates.

## 🌟 Features

- **Decentralized Campaigns**: Creator-driven campaign management with full transparency
- **STX Token Funding**: Native integration with Stacks ecosystem for seamless transactions
- **Milestone-Based Releases**: Staged funding release tied to project deliverables
- **Contributor Governance**: Democratic decision-making for milestone approvals
- **Automatic Refunds**: Smart contract-enforced refunds for unsuccessful campaigns
- **Creator Reputation**: Performance-based scoring system for project creators
- **Community Validation**: Peer review and validation mechanisms for campaigns
- **Transparent Analytics**: Real-time campaign performance and funding metrics

## 🏗️ Architecture

The system consists of two main smart contracts:

### Campaign Manager Contract (`campaign-manager.clar`)
- Creates and manages crowdfunding campaigns with funding goals and deadlines
- Handles contributor investments and tracks funding progress
- Manages milestone-based fund releases to project creators
- Processes automatic refunds for unsuccessful campaigns
- Maintains campaign lifecycle states and transitions
- Provides comprehensive campaign analytics and reporting

### Governance Controller Contract (`governance-controller.clar`)
- Enables contributor voting on campaign milestones and fund releases
- Manages creator reputation scoring based on delivery history
- Handles dispute resolution through community voting mechanisms
- Enforces platform governance rules and fee structures
- Facilitates community-driven platform improvements
- Maintains voting records and governance analytics

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) v1.0+
- [Node.js](https://nodejs.org/) v16+
- [Git](https://git-scm.com/)

### Installation

1. Clone the repository:
```bash
git clone https://github.com/daramide154/crowdfunding-platform.git
cd crowdfunding-platform
```

2. Install dependencies:
```bash
npm install
```

3. Check contract syntax:
```bash
clarinet check
```

4. Run tests:
```bash
npm test
```

### Local Development

Start a local development environment:

```bash
clarinet console
```

Deploy contracts to devnet:
```bash
clarinet deployments apply --devnet
```

## 📋 Smart Contract Functions

### Campaign Manager

#### Public Functions
- `create-campaign(title, description, goal, deadline, milestones)` - Launch new campaigns
- `contribute-to-campaign(campaign-id, amount)` - Fund existing campaigns
- `release-milestone-funds(campaign-id, milestone-id)` - Release staged funding
- `request-refund(campaign-id)` - Claim refund for failed campaigns
- `update-campaign-status(campaign-id, new-status)` - Update campaign state

#### Read-Only Functions
- `get-campaign-info(campaign-id)` - Retrieve campaign details and metrics
- `get-contribution-info(campaign-id, contributor)` - Check individual contributions
- `get-campaign-progress(campaign-id)` - View funding progress and milestones
- `calculate-refund-amount(campaign-id, contributor)` - Calculate available refunds

### Governance Controller

#### Public Functions
- `vote-on-milestone(campaign-id, milestone-id, vote)` - Vote on milestone completion
- `submit-dispute(campaign-id, reason, evidence)` - Raise campaign disputes
- `resolve-dispute(dispute-id, resolution)` - Community dispute resolution
- `update-creator-reputation(creator, performance-data)` - Update reputation scores
- `propose-governance-change(proposal-type, details)` - Platform governance proposals

#### Read-Only Functions
- `get-voting-results(campaign-id, milestone-id)` - View milestone voting outcomes
- `get-creator-reputation(creator-address)` - Check creator reputation and history
- `get-dispute-info(dispute-id)` - Access dispute details and resolution status
- `get-governance-proposal(proposal-id)` - View platform governance proposals

## 🔒 Security Features

- **Multi-signature Controls**: Critical operations require multiple approvals
- **Time-locked Releases**: Milestone funding has mandatory waiting periods
- **Reputation System**: Creator track record influences campaign visibility
- **Community Oversight**: Contributor voting prevents fraudulent campaigns
- **Automatic Refunds**: Smart contract guarantees refund availability
- **Dispute Resolution**: Fair and transparent conflict resolution process

## 🎯 Use Cases

### Creative Projects
- **Art & Design**: Digital art collections, graphic design projects, creative installations
- **Music & Entertainment**: Album production, concert tours, documentary films
- **Publishing**: Book publishing, magazine launches, educational content creation
- **Gaming**: Indie game development, gaming hardware, esports tournaments

### Technology Innovation
- **Software Development**: Open-source tools, mobile applications, blockchain projects
- **Hardware Projects**: IoT devices, consumer electronics, maker projects
- **Research & Development**: Scientific research, technology prototypes, innovation labs
- **Startups**: Early-stage funding, product development, market validation

### Social Impact
- **Community Projects**: Local initiatives, environmental conservation, social causes
- **Education**: Educational programs, scholarship funds, learning platforms
- **Healthcare**: Medical research, health awareness campaigns, accessibility tools
- **Sustainability**: Green technology, renewable energy, environmental protection

### Business Ventures
- **Product Launches**: Consumer goods, lifestyle products, fashion brands
- **Service Platforms**: Digital services, marketplace platforms, SaaS applications
- **Food & Beverage**: Restaurant openings, food product development, catering services
- **Real Estate**: Property development, co-living spaces, commercial projects

## 🧪 Testing

Run the comprehensive test suite:

```bash
# Run all tests
npm test

# Run specific test files
npm test -- campaign-manager.test.ts
npm test -- governance-controller.test.ts

# Run tests with coverage
npm run test:coverage
```

## 🌐 Deployment

### Testnet Deployment

1. Update your deployment configuration in `settings/Testnet.toml`
2. Deploy to testnet:
```bash
clarinet deployments apply --testnet
```

### Mainnet Deployment

1. Update your deployment configuration in `settings/Mainnet.toml`
2. Deploy to mainnet:
```bash
clarinet deployments apply --mainnet
```

## 📖 Usage Examples

### Creating a Campaign

```clarity
(contract-call? .campaign-manager create-campaign 
  u"Revolutionary Web3 App" 
  u"Building the future of decentralized social media" 
  u500000000 ;; 500 STX goal
  u2160 ;; ~15 days deadline
  (list {milestone: u"MVP Development", amount: u200000000}))
```

### Contributing to a Campaign

```clarity
(contract-call? .campaign-manager contribute-to-campaign 
  u1 ;; campaign-id
  u50000000) ;; 50 STX contribution
```

### Voting on Milestones

```clarity
(contract-call? .governance-controller vote-on-milestone 
  u1 ;; campaign-id
  u0 ;; milestone-id
  true) ;; approval vote
```

### Claiming Refunds

```clarity
(contract-call? .campaign-manager request-refund u1) ;; campaign-id
```

## 🏆 Platform Benefits

### For Creators
- **Global Reach**: Access to worldwide funding community
- **Reduced Barriers**: Lower entry requirements than traditional funding
- **Community Building**: Direct engagement with supporters and backers
- **Flexible Terms**: Customizable campaign parameters and milestone structures
- **Reputation Building**: Track record development for future projects

### For Contributors
- **Investment Opportunities**: Early access to innovative projects and products
- **Community Participation**: Voting rights on project milestones and decisions
- **Transparent Process**: Full visibility into fund usage and project progress
- **Risk Mitigation**: Refund guarantees and community oversight mechanisms
- **Supporting Innovation**: Direct impact on creative and technological advancement

### For the Ecosystem
- **Decentralized Finance**: Integration with broader DeFi and Web3 ecosystem
- **Innovation Funding**: Supporting development of next-generation technologies
- **Community Governance**: Democratic decision-making and platform evolution
- **Economic Growth**: Creating new funding mechanisms and business models

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guidelines](CONTRIBUTING.md) for details.

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built with [Clarity](https://clarity-lang.org/) smart contract language
- Powered by [Stacks](https://stacks.co/) blockchain
- Development tooling by [Clarinet](https://github.com/hirosystems/clarinet)

## 📞 Support

- GitHub Issues: [Create an issue](https://github.com/daramide154/crowdfunding-platform/issues)
- Documentation: [Clarity Language Reference](https://docs.stacks.co/clarity)
- Community: [Stacks Discord](https://discord.gg/stacks)

---

**⚠️ Security Notice**: This project is for educational and development purposes. Always conduct thorough security audits before deploying to mainnet with real value.