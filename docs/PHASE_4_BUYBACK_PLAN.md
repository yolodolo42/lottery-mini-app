# Phase 4: BuybackBurner - LP Auction System

## Status: Contracts Complete, Frontend Pending

**Deployed:** LotteryTreasury with buyback integration
**Pending:** BuybackBurner deployment (needs LP pair), Frontend UI

---

## Overview

BuybackBurner implements a Dutch auction that sells treasury USDC for LOTTERY-USDC LP tokens, then burns them to 0xdead. This permanently reduces LP supply, making remaining LP tokens worth more.

---

## How It Works

```
Treasury USDC (from King bids)
    │
    ▼
BuybackBurner (Dutch Auction)
    │
    ├─► User pays LP tokens
    ├─► User receives USDC
    └─► LP tokens burned to 0xdead

Result: LP supply ↓ → Each LP worth more → LOTTERY price ↑
```

---

## Contracts

### BuybackBurner.sol

**Location:** `/contracts/src/BuybackBurner.sol`

**Key Functions:**
```solidity
function getCurrentPrice() public view returns (uint256)
// Returns current USDC per 1e18 LP token (linearly decaying)

function buy(
    uint256 lpAmount,
    uint256 _epochId,
    uint256 deadline,
    uint256 maxUsdcExpected
) external
// Buy USDC with LP tokens, LP gets burned

function deposit(uint256 amount) external
// Treasury deposits USDC to be auctioned

function setParameters(
    uint256 _epochPeriod,
    uint256 _priceMultiplier,
    uint256 _minInitPrice
) external onlyOwner
// Update auction parameters
```

**Parameters:**
| Parameter | Default | Description |
|-----------|---------|-------------|
| epochPeriod | 24 hours | Auction duration |
| priceMultiplier | 12000 (1.2x) | Price boost after purchase |
| minInitPrice | 1e6 (1 USDC/LP) | Floor price |
| initPrice | 10e6 (10 USDC/LP) | Starting price |

**Dutch Auction Formula:**
```
currentPrice = initPrice × (epochPeriod - elapsed) / epochPeriod

After purchase:
newInitPrice = max(purchasePrice × 1.2, minInitPrice)
```

### LotteryTreasury.sol Updates

**New Functions:**
```solidity
function setBuybackBurner(address _burner) external onlyOwner
// Set BuybackBurner address (one-time)

function transferToBuyback(uint256 amount) external
// Governance transfers USDC from reserve to BuybackBurner
```

---

## Deployment Status

### Testnet (Base Sepolia) - 2026-01-26

| Contract | Address | Status |
|----------|---------|--------|
| MockUSDC | `0xe6E599CCb9b5550213766B0961C0A267686Df34D` | ✅ Deployed |
| MockMegapot | `0x186378F1ceD390b98283B0E776473242adbf5202` | ✅ Deployed |
| LotteryToken | `0x329fDa672F359c8422a790Df4e2BEBd96453C096` | ✅ Deployed |
| LotteryTreasury | `0x1E389cf75155E34A8901388a70c4c1B1d94e0333` | ✅ Deployed (with buyback) |
| LotteryMiner | `0x757f0cbBb7be9aaaEdFAB04632e4293BB4e0a73E` | ✅ Deployed |
| MegapotRouter | `0x71f3E2A771a23d591F7cA71d737B82c58F4322C1` | ✅ Deployed |
| ReferralCollector | `0xDA58023e0522Ab251F1dfd0CBa79fa81F0E7CBf5` | ✅ Deployed |
| **BuybackBurner** | TBD | ⏸️ Pending LP pair |
| **LP Token (LOTTERY-USDC)** | TBD | ⏸️ Not created yet |

---

## Activation Checklist

### Step 1: Accumulate LOTTERY Tokens
- Mine as King to earn 1 token/sec
- Need ~100,000 LOTTERY (~27 hours of mining)
- Or buy from other players

### Step 2: Create LP Pair on Uniswap V2

**Uniswap V2 on Base:**
- Factory: `0x8909Dc15e40173Ff4699343b6eB8132c65e18eC6`
- Router: `0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24`

**Initial Liquidity Example:**
- 100,000 LOTTERY
- 10,000 USDC
- Creates LOTTERY-USDC LP pair
- You receive LP tokens

### Step 3: Deploy BuybackBurner

```bash
USDC=0xe6E599CCb9b5550213766B0961C0A267686Df34D \
LP_TOKEN=<LP_PAIR_ADDRESS> \
forge script deployments/modules/DeployBuyback.s.sol \
  --rpc-url https://sepolia.base.org --broadcast
```

### Step 4: Configure Treasury

```bash
# Using cast or frontend
Treasury.setBuybackBurner(<BUYBACK_BURNER_ADDRESS>)
```

### Step 5: Seed First Auction

Governance transfers USDC to BuybackBurner:
```bash
Treasury.transferToBuyback(1000e6)  // 1000 USDC
```

### Step 6: Test Buy Flow

1. User approves LP tokens to BuybackBurner
2. User calls `buy(lpAmount, epochId, deadline, maxUsdcExpected)`
3. LP tokens burned to 0xdead
4. User receives USDC

---

## Frontend Integration (Pending)

### Files to Create

**1. `/frontend/src/hooks/useBuyback.ts`**
```typescript
interface BuybackState {
  epochId: bigint
  currentPrice: bigint      // USDC per 1e18 LP
  usdcAccumulated: bigint
  totalLpBurned: bigint
  startTime: bigint
  epochPeriod: bigint
  userLpBalance: bigint
  userLpAllowance: bigint
}

export function useBuyback(userAddress?: Address) {
  // Read contract state
  // Handle approve/buy flow
  // Calculate time remaining, price in next phase
}
```

**2. `/frontend/src/components/buyback/BuybackPanel.tsx`**

Display:
- Current price (USDC per LP)
- Countdown to auction end
- PAY: LP tokens input
- GET: USDC amount (calculated)
- Approve + Buy buttons
- Stats: Total LP burned, USDC distributed

**3. Update `/frontend/src/app/page.tsx`**

Add "Buyback" tab:
```typescript
type Tab = 'mine' | 'treasury' | 'buyback' | 'about'
```

---

## Testing Plan

### Contract Tests (Complete ✅)
```bash
forge test --match-path test/BuybackBurner.t.sol
# 20 tests passing
```

### Integration Tests (After LP pair created)

1. Mine as King, accumulate tokens
2. Create LP pair, get LP tokens
3. Deploy BuybackBurner
4. Governance transfers USDC
5. User approves LP tokens
6. User buys USDC with LP
7. Verify LP burned to 0xdead
8. Check price resets correctly

---

## Economic Analysis

**Example Scenario:**

Initial state:
- LP pool: 100k LOTTERY + 10k USDC
- 1000 LP tokens exist
- Each LP = 100 LOTTERY + 10 USDC = ~$20 value

Treasury auctions 1000 USDC for LP tokens:
- Auction sells 1000 USDC for ~50 LP tokens (at avg price)
- 50 LP burned to 0xdead
- Now: 950 LP tokens, same pool (100k LOTTERY + 10k USDC)
- Each LP = 105.3 LOTTERY + 10.5 USDC = ~$21 value (+5% gain)

After 100 auctions:
- 5000 LP burned (from 1000 → 500 remaining)
- Each LP worth 2x original value
- LOTTERY price supported by continuous buyback

---

## Security Features

| Feature | Implementation |
|---------|----------------|
| MEV Protection | epochId + deadline params |
| Reentrancy | ReentrancyGuard on buy() and deposit() |
| Access Control | Ownable2Step for parameters |
| CEI Pattern | State updates before transfers |
| Safe Transfers | SafeERC20 for all token ops |
| Slippage Protection | maxUsdcExpected param |

---

## Future Enhancements

1. **Auto-trigger**: Treasury auto-sends to BuybackBurner on deposit
2. **Dynamic parameters**: Adjust epochPeriod based on demand
3. **LP staking**: Stake LP tokens to earn from buybacks before burning
4. **Multi-asset support**: Auction other tokens, not just USDC

---

## References

- GlazeCorp implementation: `/Users/binnyarora/projects/glazecorp-webapp`
- Contract code: `/contracts/src/BuybackBurner.sol`
- Tests: `/contracts/test/BuybackBurner.t.sol`
- Deployment: `/contracts/deployments/modules/DeployBuyback.s.sol`
