# $LOTTERY Tokenomics

## Token Overview

| Property | Value |
|----------|-------|
| Name | LOTTERY |
| Symbol | $LOTTERY |
| Chain | Base |
| Standard | ERC-20 (with ERC20Votes) |
| Max Supply | 100,000,000 (100M) |
| LP Premine | 5,000,000 (5%) |
| Emission Supply | 95,000,000 (95%) |

---

## Emission Schedule

### Constant Emission with Hard Cap

```
Rate: 1 $LOTTERY per second (while King exists)
Max per reign: 7 days (604,800 tokens)
Hard cap: 100M total supply
```

| Period | Tokens | Cumulative |
|--------|--------|------------|
| Day 1 | 86,400 | 86,400 |
| Week 1 | 604,800 | 604,800 |
| Month 1 | ~2.6M | ~2.6M |
| Year 1 | ~31.5M | ~31.5M |
| Cap reached | ~3 years | 100M |

Emissions stop permanently when totalSupply hits 100M.

---

## Token Distribution

| Allocation | Amount | Purpose |
|------------|--------|---------|
| LP Premine | 5M (5%) | Initial LOTTERY-USDC liquidity |
| King Emissions | 95M (95%) | Earned by Kings at 1/sec |

No team allocation. No VC allocation. No airdrop. 100% goes to LP and players.

### Initial LP

- 5,000,000 LOTTERY + 1,000 USDC
- Initial price: $0.0002 per LOTTERY
- LP tokens held by deployer

---

## Mining: The King Game

### How It Works

1. **Bid USDC** at or above the current price to become King
2. **Earn 1 $LOTTERY/sec** while you're King (max 7 days)
3. **Get outbid?** Receive 20-80% of the new bid + accumulated LOTTERY + referral fees

### Fee Split (per bid)

```
USDC Bid
    │
    ├── 20-80% → Previous King (time-decaying)
    │
    ├── 5% → Creator (fixed, immutable)
    │
    └── 15-75% → Treasury (residual)
                  ├── ~67% → Megapot tickets (auto-purchased)
                  └── ~33% → Reserve pool
```

### King Income Streams

| Stream | Source | When |
|--------|--------|------|
| USDC payout | New bidder's USDC | On dethrone |
| $LOTTERY emissions | Token minting | On dethrone or claimEmissions() |
| Referral fees (50%) | Megapot referral program | Auto-harvested on dethrone/claim |

---

## Price Mechanics

### Price Decay (Dutch Auction)

After each bid, the minimum price to dethrone the King decays over 24 hours:

| Phase | Time | Price |
|-------|------|-------|
| A | 0 → 1h | 2x → 1.1x last bid |
| B | 1h → 24h | 1.1x → $10 |
| C | 24h+ | $10 floor |

### Payout Decay

The previous King's share of the new bid decays over time:

| Phase | Time | King Gets |
|-------|------|-----------|
| 1 | 0 → 1h | 80% |
| 2 | 1h → 6h | 80% → 60% |
| 3 | 6h → 24h | 60% → 20% |
| 4 | 24h+ | 20% |

As King payout decreases, Treasury share increases proportionally.

---

## Treasury Mechanics

### Dual Pool System

Every Treasury deposit is split:
- **Megapot Pool** (~67%): Auto-buys Megapot lottery tickets
- **Reserve Pool** (~33%): Governance-controlled

### Revenue Streams into Treasury

1. **Bid residual** (15-75% of each bid)
2. **Referral fees** (50% of harvested referral fees)
3. **Megapot winnings** (auto-claimed on deposit)

### Outflows

1. **Megapot tickets** — purchased automatically via MegapotRouter
2. **BuybackBurner** — owner can transfer reserve USDC to Dutch auction
3. **Governance** — owner can withdraw from reserve

---

## Deflationary Mechanics: BuybackBurner

The BuybackBurner creates permanent liquidity through a Dutch auction:

1. Treasury sends USDC to BuybackBurner
2. Users sell LOTTERY-USDC LP tokens for USDC at the auction price
3. BuybackBurner sends acquired LP tokens to `0xdead` (permanently locked)

This removes LP from circulation, permanently locking liquidity and creating deflationary pressure on the LOTTERY supply.

| Parameter | Value |
|-----------|-------|
| Epoch period | 24 hours |
| Price multiplier | 1.2x per epoch |
| Minimum price | 1 USDC per LP |
| Starting price | 10 USDC per LP |

---

## Referral Fee Loop

A self-reinforcing revenue cycle:

```
King bids → Treasury gets USDC → Buys Megapot tickets
    ↑                                      │
    │                              Referral fees (10%)
    │                                      │
    └──── 50% back to King ◄───── ReferralCollector
                                           │
                                    50% to Treasury
```

The more bids → more tickets → more referral fees → more King income → more incentive to bid.

---

## Risk Factors

| Risk | Mitigation |
|------|------------|
| Low activity | Price decay to $10 floor ensures accessibility |
| Inflation | 100M hard cap, BuybackBurner deflation |
| Smart contract | Audited, 131 tests, fork-tested on mainnet |
| Megapot dependency | Best-effort try/catch, silent failures |
| One-time setters | Accepted risk, prevents malicious reconfiguration |
