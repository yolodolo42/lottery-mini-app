# $LOTTERY

King-of-the-Hill DeFi game on Base. Bid USDC to become King and earn $LOTTERY tokens.

---

## How It Works

1. **Bid USDC** to become the King.
2. **Earn 1 $LOTTERY/sec** while you're King (up to 7 days)
3. **Get outbid?** Receive 20-80% of the new bid (time-decaying)
4. **Price decays** over 24 hours (2x→1.1x→$10) to keep the game moving

---

## Contracts

### Base Mainnet

| Contract | Address |
|----------|---------|
| **LotteryToken** | [`0x07911ee281161f498Ae86acBad93F397ba35E0D3`](https://basescan.org/address/0x07911ee281161f498Ae86acBad93F397ba35E0D3) |
| **LotteryMiner** | [`0xd1DA10c6179693F05d15D420f5FE49405Da8a52B`](https://basescan.org/address/0xd1DA10c6179693F05d15D420f5FE49405Da8a52B) |
| **LotteryTreasury** | [`0xa680443Bc34E65D1fBaA0BF47ebEc5EF4f370E04`](https://basescan.org/address/0xa680443Bc34E65D1fBaA0BF47ebEc5EF4f370E04) |
| **MegapotRouter** | [`0xDD577b9663fCb8235e9476DCc1A3C2E6CC8c9d87`](https://basescan.org/address/0xDD577b9663fCb8235e9476DCc1A3C2E6CC8c9d87) |
| **ReferralCollector** | [`0x45C666A3f7bCE2CF5c346422b0d46EC50987A062`](https://basescan.org/address/0x45C666A3f7bCE2CF5c346422b0d46EC50987A062) |
| **BuybackBurner** | [`0x341f4295Cec19950D3ba441Dc4C45bD06d13AB5d`](https://basescan.org/address/0x341f4295Cec19950D3ba441Dc4C45bD06d13AB5d) |
| **LP Pair** | [`0x6e6Da38161E0d345d82C4F3aFC370087bF8F2a23`](https://basescan.org/address/0x6e6Da38161E0d345d82C4F3aFC370087bF8F2a23) |

### Frontend

- **Live:** [frontend-yolodolos-projects.vercel.app](https://frontend-yolodolos-projects.vercel.app)
- Next.js 16 + Tailwind CSS 4
- Farcaster Mini App integration
- Real-time contract data via wagmi

---

## Quick Start

### Contracts

```bash
cd contracts
forge build
forge test  # 131 tests (unit + fork)
```

Deploy:
```bash
source ../.env
forge script deployments/DeployAll.s.sol:DeployAllScript \
  --rpc-url $BASE_RPC_URL --broadcast
```

### Frontend

```bash
cd frontend
npm install
npm run dev  # http://localhost:3000
```

---

## Tokenomics

### Game Mechanics

| Parameter | Value |
|-----------|-------|
| Emission rate | 1 $LOTTERY/sec |
| Max supply | 100M tokens |
| LP premine | 5M (5%) |
| Max emission period | 7 days per reign |
| Price decay | 2x→1.1x→$10 (24h) |
| Payout decay | 80%→20% (24h) |
| Min bid | $10 USDC |

### Fee Split (per bid)

| Recipient | Share |
|-----------|-------|
| Previous King | 20-80% (time-decaying) |
| Creator | 5% (fixed) |
| Treasury | 15-75% (residual) |

Treasury uses funds for:
- **Megapot lottery tickets** (~67%, auto-purchased on deposit)
- **Reserve pool** (~33%, governance-controlled)
- **LP buyback & burn** (Dutch auction via BuybackBurner)

### Referral Fee Loop

MegapotRouter captures 10% referral fees from Megapot ticket purchases. On every `mine()` or `claimEmissions()`, fees are auto-harvested:
- 50% → current King
- 50% → Treasury reserve

### Auto-Claim Winnings

If Treasury wins a Megapot jackpot, winnings are automatically claimed on every `deposit()` and added to the reserve pool.

---

## Project Structure

```
lottery/
├── contracts/          # Solidity contracts (Foundry)
│   ├── src/            # Contract source (6 contracts)
│   ├── test/           # Tests (131 passing)
│   └── deployments/    # Deployment scripts
├── frontend/           # Next.js Farcaster Mini App
│   └── src/            # React components & hooks
└── docs/               # Documentation
```

---

## Features

- [x] Phase 1: Price decay + payout decay (liveness loop)
- [x] Phase 2: Referral fee capture (cashflow loop)
- [x] Phase 3: BuybackBurner (LP Dutch auction + burn)
- [x] Phase 4: Auto-harvest referral fees + auto-claim winnings
- [ ] Phase 5: Governance staking (voting power only)

---

## License

MIT
