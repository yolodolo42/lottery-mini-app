# $LOTTERY - System Architecture

## Overview

A Farcaster Mini App on Base where users bid USDC to become "King" and earn $LOTTERY tokens. The system generates revenue through Megapot lottery ticket purchases and referral fees.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                     $LOTTERY SYSTEM (v2)                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────┐  │
│  │ LotteryMiner│───▶│ LotteryTreasury  │───▶│  Megapot   │  │
│  │ (King game) │    │ (fee routing)    │    │ (tickets)  │  │
│  └──────┬──────┘    └────────┬─────────┘    └─────┬──────┘  │
│         │                    │                     │         │
│    mint │           deposit  │            referral │ fees    │
│         ▼                    ▼                     ▼         │
│  ┌─────────────┐    ┌──────────────────┐    ┌────────────┐  │
│  │ LotteryToken│    │ BuybackBurner    │    │ Referral   │  │
│  │ (ERC20+Vote)│    │ (LP auction)     │    │ Collector  │  │
│  └─────────────┘    └──────────────────┘    └────────────┘  │
│                                                              │
│  ┌─────────────┐                                             │
│  │MegapotRouter│  Routes ticket purchases with referral      │
│  └─────────────┘                                             │
└──────────────────────────────────────────────────────────────┘
```

---

## Contracts (6 total)

### 1. LotteryToken.sol
ERC20 with voting (ERC20Votes) and one-time LP premine.

- 100M max supply hard cap
- 5M premine (5%) minted directly to LP pair
- Only LotteryMiner can mint (via emissions)

### 2. LotteryMiner.sol
Core game logic — King-of-the-hill with USDC bids.

- **Price decay:** 2x→1.1x (1h), 1.1x→$10 (23h), $10 floor after 24h
- **Payout decay:** 80% (first hour) → 20% (after 24h)
- **Emissions:** 1 $LOTTERY/sec, capped at 7 days per reign
- **MEV protection:** epochId + deadline on mine()
- **Auto-harvest:** Referral fees harvested on mine() and claimEmissions()

### 3. LotteryTreasury.sol
Receives treasury share of bids, routes to Megapot and reserve.

- **Megapot pool** (~67%): Auto-purchases tickets on every deposit
- **Reserve pool** (~33%): Governance-controlled
- **Auto-claim:** Megapot winnings claimed on every deposit
- **BuybackBurner:** Can transfer reserve to LP auction

### 4. MegapotRouter.sol
Purchases Megapot tickets with ReferralCollector as referrer.

### 5. ReferralCollector.sol
Harvests Megapot referral fees (10% of ticket cost).

- 50% → current King
- 50% → Treasury reserve

### 6. BuybackBurner.sol
Dutch auction selling USDC for LOTTERY-USDC LP tokens, then burns them to 0xdead.

- 24h epoch periods with 1.2x price multiplier
- Creates permanent, locked liquidity

---

## Fee Split (per bid)

| Recipient | Share | Calculation |
|-----------|-------|-------------|
| Previous King | 20-80% | Time-decaying (80% at 0h → 20% at 24h) |
| Creator | 5% | Fixed, immutable |
| Treasury | 15-75% | Residual (grows as King payout shrinks) |

---

## Key Mechanics

### Price Decay (3 phases)
- **Phase A (0-1h):** 2x → 1.1x last bid (linear)
- **Phase B (1h-24h):** 1.1x → $10 floor (linear)
- **Phase C (24h+):** $10 absolute minimum

### Payout Decay (4 phases)
- **Phase 1 (0-1h):** 80% to previous King
- **Phase 2 (1h-6h):** 80% → 60% (linear)
- **Phase 3 (6h-24h):** 60% → 20% (linear)
- **Phase 4 (24h+):** 20% floor

### Referral Fee Loop
1. Treasury auto-buys Megapot tickets via MegapotRouter
2. MegapotRouter sets ReferralCollector as referrer
3. Megapot accumulates 10% referral fees
4. On mine()/claimEmissions(), fees auto-harvested (50% King, 50% Treasury)

---

## Deployed Addresses

See [README.md](README.md) for Base mainnet contract addresses.
