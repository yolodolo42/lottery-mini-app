# $LOTTERY Tokenomics

## Token Overview

| Property | Value |
|----------|-------|
| Name | LOTTERY |
| Symbol | $LOTTERY |
| Chain | Base |
| Standard | ERC-20 |
| Initial Supply | 0 |
| Max Supply | Unlimited (inflationary) |

---

## Emission Schedule

### Constant Emission Model

```
Rate: 1 $LOTTERY per second (forever)

Daily:    86,400 tokens
Weekly:   604,800 tokens
Monthly:  ~2,592,000 tokens
Yearly:   ~31,536,000 tokens
```

### Why Constant Emission?

| Halving Model | Constant Model |
|---------------|----------------|
| Front-loads rewards to early miners | Even distribution over time |
| Creates artificial scarcity | Value from utility, not scarcity |
| Treasury revenue declines over time | Treasury revenue stable forever |
| Complex tokenomics | Simple and predictable |

For a lottery-focused token, **sustained treasury revenue** matters more than artificial scarcity.

---

## Mining Mechanism: The "King" Game

### How It Works

1. **Dutch Auction Price**
   - Price starts at 2× the last winning bid
   - Price decays linearly to 0 over 1 hour
   - Anyone can bid at or above current price

2. **Becoming King**
   - Pay USDC at current price
   - Become the "Lottery King"
   - Start earning 1 $LOTTERY per second

3. **Staying King**
   - Earn emissions until someone outbids you
   - Receive 80% of the next bid as profit
   - Claim accumulated $LOTTERY anytime

### Example Flow

```
Hour 0:
├── Alice bids 100 USDC (first bid, no minimum)
├── Fee split: 80 USDC → treasury*, 5 USDC → creator, 15 USDC → treasury
├── Alice becomes King
└── Alice starts earning 1 $LOTTERY/second

* First bid has no previous king, so 80% goes to treasury

Hour 2:
├── Bob bids 150 USDC
├── Fee split: 120 USDC → Alice, 7.5 USDC → creator, 22.5 USDC → treasury
├── Bob becomes King
├── Alice earned: 2 hours × 3600 sec = 7,200 $LOTTERY
└── Alice profit: 120 - 100 = +20 USDC + 7,200 tokens

Hour 3 (no bids):
├── Price decayed to 0
├── Bob still King, still earning
└── Anyone can bid minimum (10% above last = 165 USDC)
```

---

## Fee Distribution

### On Each Mining Bid

```
USDC Bid
    │
    ├── 80% → Previous King (reward for playing)
    │
    ├── 5%  → Creator (hardcoded, immutable)
    │
    └── 15% → Treasury
              ├── 10% → Megapot tickets (auto, configurable)
              └── 5%  → Reserve (owner-controlled)
```

### Fee Recipients

| Recipient | Share | Purpose |
|-----------|-------|---------|
| Previous King | 80% | Incentivizes participation, creates competitive game |
| Creator | 5% | Sustainable revenue for protocol creator |
| Megapot | 10% | Auto-buys lottery tickets (configurable 0-15%) |
| Reserve | 5% | Future use: buybacks, distributions, ops |

### Edge Cases

**First Bid (No Previous King):**
- 80% goes to treasury instead
- Total treasury: 80% + 15% = 95%
- Creator still gets 5%

**No Frontend Referrer:**
- N/A (removed frontend fee)

---

## Treasury Mechanics

### Dual Pool System

```
Every bid → 15% to Treasury
Treasury splits into two pools:

┌─────────────┐
│  megapotBps │ (default 10%, configurable)
│  = 1000     │
└──────┬──────┘
       │
       ▼
┌─────────────────┐     ┌─────────────────┐
│  Megapot Pool   │     │  Reserve Pool   │
│  (auto tickets) │     │  (owner ctrl)   │
│  10% of bid     │     │  5% of bid      │
└─────────────────┘     └─────────────────┘
```

### Megapot Pool

- Accumulates 10% of each bid (configurable 0-15%)
- Anyone can call `processTickets()` to buy lottery tickets
- Owner can adjust via `setMegapotBps()`

### Reserve Pool

- Accumulates remainder (5% default)
- Owner-controlled via `withdraw()` and `execute()`
- Future uses: DONUT buyback, distributions, operations

---

## Price Discovery

### Dutch Auction Mechanics

```
Start Price = 2 × Last Bid
Decay Period = 1 hour
End Price = 0

Price at time t:
price(t) = startPrice × (1 - t/decayPeriod)

Example:
├── Last bid: 100 USDC
├── Start price: 200 USDC
├── After 30 min: 100 USDC
├── After 45 min: 50 USDC
├── After 60 min: 0 USDC
```

### Minimum Bid Rules

| Condition | Minimum Bid |
|-----------|-------------|
| First ever bid | Any amount > 0 |
| During decay | Current auction price |
| After full decay | 10% above last bid |

---

## Token Utility

### Current Utility

1. **Speculation** - Price discovery via market
2. **Future Claims** - May entitle holder to jackpot distribution

### Planned Utility (Future)

1. **Jackpot Share** - If Megapot tickets win, holders claim pro-rata
2. **Governance** - Vote on treasury usage
3. **Staking** - Stake for enhanced rewards

---

## Economic Flows

### Mining Flow

```
User has USDC
       │
       ▼
┌─────────────────┐
│ mine(amount)    │
│                 │
│ Pay USDC        │
│ Become King     │
│ Earn emissions  │
└─────────────────┘
       │
       ├── 80% USDC → Previous King
       ├── 5% USDC  → Creator
       └── 15% USDC → Treasury
```

### Emission Flow

```
Time passes
       │
       ▼
┌─────────────────┐
│ King earns      │
│ 1 token/second  │
└─────────────────┘
       │
       ▼
┌─────────────────┐
│ claimEmissions()│
│                 │
│ Mint $LOTTERY   │
│ to King         │
└─────────────────┘
```

---

## Supply Dynamics

### Inflationary Pressure

- Constant 1 token/second emission
- No max supply
- Supply grows linearly forever

### Deflationary Mechanisms (Future)

- Treasury could buy and burn $LOTTERY
- Fee burns (if implemented)
- Unclaimed emissions (if King doesn't claim)

### Supply Projections

| Time | Circulating Supply |
|------|-------------------|
| Day 1 | 86,400 |
| Week 1 | 604,800 |
| Month 1 | ~2.6M |
| Year 1 | ~31.5M |
| Year 5 | ~157.7M |

---

## Comparison to DONUT

| Aspect | DONUT | $LOTTERY |
|--------|-------|----------|
| Mining Token | ETH | USDC |
| Emission | Halving | Constant |
| Fee Split | 80/15/5 | 80/5/15 |
| Governance | gDONUT voting | TBD |
| Treasury Use | Revenue Router | Flexible |

---

## Risk Factors

### Inflation Risk
- Unlimited supply means continuous dilution
- Mitigated by: utility, burns, demand

### King Game Risk
- Low activity = low treasury revenue
- Mitigated by: compelling rewards, community

### Smart Contract Risk
- New contracts, not audited
- Mitigated by: simple design, testing

---

## Summary

| Metric | Value |
|--------|-------|
| Emission Rate | 1 token/second |
| Mining Currency | USDC |
| Previous King Fee | 80% |
| Creator Fee | 5% |
| Treasury Fee | 15% |
| Auction Decay | 1 hour |
| Min Bid Increase | 10% |
