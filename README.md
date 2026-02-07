# $LOTTERY

King-of-the-Hill DeFi game on Base. Bid USDC to become King and earn $LOTTERY tokens.

---

## How It Works

1. **Bid USDC** to become the King.
2. **Earn 1 $LOTTERY/sec** while you're King
3. **Get outbid?** Receive 20-80% of the new bid (time-decaying)
4. **Price decays** over 24 hours (2x→1.1x→$1) to keep the game moving

---

## Architecture

### Contracts (Base Sepolia)

| Contract | Purpose | Address |
|----------|---------|---------|
| **LotteryMiner** | Core game logic | `0x757f0cbBb7be9aaaEdFAB04632e4293BB4e0a73E` |
| **LotteryToken** | $LOTTERY ERC20 with voting | `0x329fDa672F359c8422a790Df4e2BEBd96453C096` |
| **LotteryTreasury** | Fee routing & Megapot | `0x1E389cf75155E34A8901388a70c4c1B1d94e0333` |
| **MegapotRouter** | Referral fee capture | `0x71f3E2A771a23d591F7cA71d737B82c58F4322C1` |
| **ReferralCollector** | Fee distribution | `0xDA58023e0522Ab251F1dfd0CBa79fa81F0E7CBf5` |
| **BuybackBurner** | LP auction (Phase 4) | TBD |

### Frontend

- Next.js 16 + Tailwind CSS 4
- Farcaster Mini App integration
- Vintage 1920s lottery ticket aesthetic
- Real-time contract data via wagmi

---

## Quick Start

### Contracts

```bash
cd contracts
forge build
forge test  # 108 tests
```

Deploy to testnet:
```bash
source ../.env
TESTNET=true forge script deployments/DeployAll.s.sol:DeployAllScript \
  --rpc-url https://sepolia.base.org --broadcast
```

### Frontend

```bash
cd frontend
npm install
npm run dev  # http://localhost:3000
```

Deploy to Vercel:
```bash
vercel --prod
```

---

## Tokenomics

### Game Mechanics

| Parameter | Value |
|-----------|-------|
| Emission rate | 1 $LOTTERY/sec |
| Max supply | 100M tokens |
| Price decay | 2x→1.1x→$1 (24h) |
| Payout decay | 80%→20% (24h) |

### Fee Split (per bid)

| Recipient | Share |
|-----------|-------|
| Previous King | 20-80% (time-decaying) |
| Creator | 5% (fixed) |
| Treasury | 15-75% (residual) |

Treasury uses funds for:
- Megapot lottery tickets (auto-purchased)
- Reserve (governance-controlled)
- LP buyback & burn (Phase 4)

---

## Project Structure

```
lottery/
├── contracts/          # Solidity contracts (Foundry)
│   ├── src/            # Contract source
│   ├── test/           # Tests (108 passing)
│   └── deployments/    # Deployment scripts
├── frontend/           # Next.js app
│   └── src/            # React components & hooks
├── docs/               # Documentation
│   ├── V2_IMPLEMENTATION_PLAN.md
│   └── PHASE_4_BUYBACK_PLAN.md
└── PROGRESS.md         # Project status
```

---

## Documentation

- **PROGRESS.md** - Current status and recent work
- **contracts/README.md** - Contract details
- **frontend/README.md** - Frontend setup
- **docs/PHASE_4_BUYBACK_PLAN.md** - LP auction system
- **contracts/deployments/README.md** - Deployment guide

---

## Features Roadmap

- [x] Phase 1: Price decay + payout decay (liveness loop)
- [x] Phase 2: Referral fee capture (cashflow loop)
- [ ] Phase 3: Governance staking (voting power only)
- [ ] Phase 4: LP buyback & burn (contracts ready, pending LP pair)

---

## License

MIT
