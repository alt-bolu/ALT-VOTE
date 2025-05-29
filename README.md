# 🗳️ ALT-VOTE: Decentralized Governance on Bitcoin via Stacks

**ALT-VOTE** is a decentralized governance platform built using **Clarity smart contracts** on the **Stacks blockchain**, secured by Bitcoin. ALT-VOTE enables token-based voting where contributors and investors receive a native governance token, `altvote-token`, that gives them direct control over project decisions like fund allocation and initiative selection.

---

## 📘 Overview

ALT-VOTE empowers decentralized communities to manage project decisions democratically. Participants earn or purchase governance tokens that represent one unit of voting power. These tokens allow holders to:

* Create and vote on proposals
* Decide how treasury funds are used
* Select which projects or features are prioritized

Built on the Stacks blockchain, ALT-VOTE combines transparency, immutability, and Bitcoin-level security.

---

## 🧱 Built With

* **[Clarity](https://docs.stacks.co/docs/clarity-overview)** – Smart contract language for Stacks
* **[Clarinet](https://github.com/hirosystems/clarinet)** – Local dev toolchain for Clarity
* **[Stacks Blockchain](https://stacks.co/)** – Bitcoin Layer-2 for smart contracts

---

## 📦 Project Structure

```bash
alt-vote/
├── contracts/              # Clarity smart contracts
│   ├── altvote-token.clar        # Governance token
│   ├── governance.clar           # Voting and proposal logic
│   └── proposal-registry.clar    # Proposal tracking
├── settings/
│   └── Devnet.toml         # Local devnet config
├── tests/
│   └── governance_test.ts  # Test suite using Clarinet
├── Clarinet.toml           # Clarinet project config
└── README.md
```

---

## ⚙️ Setup & Development

### Prerequisites

* [Install Clarinet](https://docs.hiro.so/clarinet/getting-started/installation)
* Node.js ≥ 18.x (for running tests)
* [VSCode Clarity plugin](https://marketplace.visualstudio.com/items?itemName=hirosystems.clarity)

### Getting Started

```bash
# Clone the repository
git clone https://github.com/your-org/alt-vote.git
cd alt-vote

# Start the Clarinet devnet
clarinet devnet
```

### Compile Smart Contracts

```bash
clarinet check
```

### Run Tests

```bash
clarinet test
```

---

## 🧩 Core Contracts

### 1. `altvote-token.clar`

* **Token Standard**: SIP-010 (Fungible Token)
* **Functions**:

  * `mint`
  * `transfer`
  * `balance-of`
  * `get-total-supply`

### 2. `governance.clar`

* Allows users to:

  * Create proposals
  * Cast votes
  * Finalize proposals
* Voting uses simple majority and quorum thresholds.

### 3. `proposal-registry.clar`

* Tracks proposal lifecycle:

  * Draft
  * Voting
  * Finalized
* Supports proposal metadata (linked off-chain via IPFS or other system)

---

## 🛠 Governance Flow

```plaintext
Token Issuance → Proposal Creation → Voting → Execution
```

1. **Earn or Buy Tokens** – Contributors are rewarded; investors buy in.
2. **Create Proposal** – Token holders submit proposals.
3. **Community Voting** – Holders vote using their tokens.
4. **Execution** – Proposals that meet quorum and majority are enacted.

---

## 🧠 Tokenomics

* **Token Name**: ALT-VOTE Token
* **Symbol**: ALTV
* **Distribution**:

  * Contributors: % allocated via minting logic
  * Investors: % allocated via initial sale
  * DAO Treasury: % held for future allocation via vote

---

## 🔐 Security & Best Practices

* Clarity’s predictability ensures safe contract behavior.
* Contracts will undergo audits before mainnet deployment.
* DAO governance will eventually transition to full on-chain automation.

---

## 📄 Example Proposal Use Cases

* Allocate funding to a developer grant
* Approve a marketing budget
* Vote to onboard a new contributor
* Elect a DAO council

---

## 🤝 Contributing

We welcome contributions!

### Steps

1. Fork this repo
2. Create a feature branch
3. Submit a pull request

Please review [CONTRIBUTING.md](./CONTRIBUTING.md) and [CODE\_OF\_CONDUCT.md](./CODE_OF_CONDUCT.md) before submitting PRs.

---

## 📚 Resources

* [Stacks Documentation](https://docs.stacks.co/)
* [Clarity Language Reference](https://docs.stacks.co/docs/clarity-language)
* [Clarinet Docs](https://docs.hiro.so/clarinet/overview)

---

## 📝 License

MIT License – see [LICENSE](./LICENSE)

---

## 🌍 Community

* Discord: [Join the conversation](https://discord.gg/stacks)
* Twitter: [@altvote](https://twitter.com/altvote)
* Forum: [forum.altvote.org](https://forum.altvote.org)

---

*Built on Bitcoin. Owned by the community.*
— *The ALT-VOTE Team*
