# $LOTTERY - Implementation Plan (Simplified)

## Overview

A Farcaster Mini App for $LOTTERY token with:
- **King Game Mining** - Compete to earn $LOTTERY via USDC bids
- **Treasury Revenue** - Accumulates 15% of mining fees
- **Future Distribution** - Treasury has hooks for adding distribution logic later

**Philosophy**: Ship simple now, add distribution complexity later.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                   $LOTTERY SYSTEM                        │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  MINE $LOTTERY              TREASURY                    │
│  (King game)          →    (accumulates USDC)           │
│                                                         │
│  ┌─────────────┐          ┌─────────────────┐          │
│  │ LotteryMiner│───15%───▶│ LotteryTreasury │          │
│  │             │          │                 │          │
│  │ 80% → prev  │          │ 10% → Megapot   │          │
│  │ 5%  → creator          │ 5% → Reserve    │          │
│  └─────────────┘          └─────────────────┘          │
│         │ mint                                          │
│         ▼                                               │
│  ┌─────────────┐                                        │
│  │ LotteryToken│                                        │
│  │   (ERC20)   │                                        │
│  └─────────────┘                                        │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Contracts (3 total)

### 1. LotteryToken.sol
Standard ERC20 with minter role.

```solidity
// Key features
- ERC20 token "LOTTERY"
- Only LotteryMiner can mint
- Standard transfer (no tax)
```

### 2. LotteryMiner.sol
King game with USDC mining.

```solidity
// Mining mechanics
- Dutch auction: price starts at 2x last bid, decays to 0 over 1 hour
- Bidder becomes "King", earns 1 $LOTTERY/second
- Fee split (automatic on each bid):
  - 80% → Previous King
  - 5%  → Creator (hardcoded, immutable)
  - 15% → Treasury

// Key functions
mine(bidAmount)            // Become King
claimEmissions()           // Claim earned $LOTTERY
getCurrentPrice()          // View current auction price

// Key state
address public immutable creator;    // Receives 5%
address public treasury;             // Receives 15%
```

### 3. LotteryTreasury.sol
Receives 15% of fees, auto-buys Megapot tickets, holds reserve.

```solidity
// Automatic (permissionless)
processTickets()           // Buy Megapot tickets with megapotPool

// Owner functions
withdraw(address to, uint256 amount)  // Withdraw from reserve
execute(address target, bytes data)   // Call any contract
setMegapotBps(uint256 bps)            // Change Megapot % (default 1000 = 10%)

// Key state
uint256 public megapotBps = 1000;     // 10% of total bid (configurable)
uint256 public megapotPool;           // Accumulates for Megapot
uint256 public reservePool;           // Remaining (5% default)
```

**How it works:**
1. Miner sends 15% to Treasury
2. Treasury splits: megapotBps% → megapotPool, rest → reservePool
3. Anyone calls `processTickets()` → buys Megapot tickets
4. Owner can change megapotBps anytime (0-1500 range)

---

## Project Structure

```
lottery/
├── contracts/
│   ├── src/
│   │   ├── LotteryToken.sol
│   │   ├── LotteryMiner.sol
│   │   └── LotteryTreasury.sol
│   ├── test/
│   │   └── Lottery.t.sol
│   ├── script/
│   │   └── Deploy.s.sol
│   └── foundry.toml
│
└── frontend/
    ├── src/
    │   ├── app/
    │   │   ├── layout.tsx
    │   │   ├── page.tsx           # Main app (sdk.actions.ready())
    │   │   └── api/
    │   ├── components/
    │   │   ├── mining/
    │   │   │   ├── KingStatus.tsx
    │   │   │   ├── MineButton.tsx
    │   │   │   └── ClaimEmissions.tsx
    │   │   └── stats/
    │   │       ├── TokenBalance.tsx
    │   │       └── TreasuryBalance.tsx
    │   ├── hooks/
    │   │   ├── useMiner.ts
    │   │   └── useTreasury.ts
    │   ├── lib/
    │   │   ├── contracts.ts
    │   │   └── wagmiConfig.ts
    │   └── public/
    │       └── .well-known/farcaster.json
    ├── next.config.ts
    └── vercel.json
```

---

## Implementation Steps

### Phase 1: Setup
1. Initialize Foundry project in `contracts/`
2. Initialize Next.js project in `frontend/`
3. Install dependencies (OpenZeppelin, wagmi, farcaster-sdk)

### Phase 2: Smart Contracts
1. **LotteryToken.sol** - ERC20 with minter
2. **LotteryMiner.sol** - King game, emissions, fee split
3. **LotteryTreasury.sol** - Simple accumulator with distribution hooks
4. Write tests on Base fork
5. Deploy script

### Phase 3: Frontend
1. Farcaster SDK setup (`sdk.actions.ready()`)
2. wagmi config with Farcaster connector
3. Mining UI (King status, bid, claim emissions)
4. Stats UI (token balance, treasury balance)

### Phase 4: Deploy
1. Deploy contracts to Base
2. Deploy frontend to Vercel
3. Test full flow in Warpcast

---

## Key Files to Create

| File | Purpose |
|------|---------|
| `contracts/src/LotteryToken.sol` | ERC20 token with minter |
| `contracts/src/LotteryMiner.sol` | King game mining |
| `contracts/src/LotteryTreasury.sol` | Revenue accumulator + future hooks |
| `frontend/src/app/page.tsx` | Main app with sdk.ready() |
| `frontend/src/lib/contracts.ts` | Contract ABIs + addresses |
| `frontend/public/.well-known/farcaster.json` | Farcaster manifest |

---

## Contract Addresses (Base)

| Contract | Address |
|----------|---------|
| USDC | `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913` |
| Megapot | `0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95` |
| LotteryToken | TBD (deploy) |
| LotteryMiner | TBD (deploy) |
| LotteryTreasury | TBD (deploy) |

---

## Config Values

| Parameter | Value |
|-----------|-------|
| Emission rate | 1 $LOTTERY/second |
| Prev King fee | 80% |
| Creator fee | 5% (hardcoded, immutable) |
| Treasury fee | 15% total |
| └─ Megapot fee | 10% (configurable, default) |
| └─ Reserve fee | 5% (remainder) |
| Price decay | 1 hour |
| Min bid increase | 10% |

---

## Treasury Mechanics

Treasury receives 15% of all mining fees, then:

1. **Megapot Pool** (default 10%)
   - Accumulates for lottery tickets
   - Anyone can call `processTickets()` to buy
   - Owner can change % via `setMegapotBps()`

2. **Reserve Pool** (remaining 5%)
   - Owner-controlled
   - Future uses: DONUT buyback, distributions, ops
