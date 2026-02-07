# Treasury & Buyback

## Treasury Overview

The LotteryTreasury receives the **residual from every bid** (15-75%, depending on the previous king's payout decay). It splits incoming USDC into two pools:

| Pool | Default Share | Purpose |
|------|---------------|---------|
| Megapot | ~67% of deposit | Auto-buy lottery tickets |
| Reserve | ~33% of deposit | Governance-controlled |

The Megapot/reserve split is configurable by the owner via `setMegapotBps()` (range: 0-100% of deposit).

## Megapot Integration

Every bid triggers an automatic Megapot ticket purchase:

1. **Bid happens.** Treasury share (15-75%) goes to LotteryTreasury.
2. **Treasury splits the deposit** between Megapot pool and reserve pool.
3. **Auto-purchase.** Treasury buys Megapot tickets immediately.
4. **Routing.** Purchases go through MegapotRouter with referral set to ReferralCollector.
5. **Referral fees accumulate.** Megapot pays referral fees to the ReferralCollector.

If the Megapot purchase fails (e.g. Megapot is paused or unavailable), the USDC stays in the Megapot pool and retries automatically on the next deposit.

If Megapot becomes permanently unavailable, governance can rescue stuck funds via `rescueMegapotPool()`.

## Referral Fee Loop

```
Every bid
    └─ 15-75% to Treasury (residual after prev king + creator)
         ├─ ~67% buys Megapot tickets (via MegapotRouter)
         │    └─ Megapot pays referral fees
         │         └─ ReferralCollector
         │              ├─ 50% → Current King (USDC)
         │              └─ 50% → Treasury reserve (USDC)
         └─ ~33% to reserve pool
```

The `harvest()` function on ReferralCollector is **permissionless**. Anyone can call it to distribute pending referral fees.

## Reserve Pool

The reserve pool holds USDC not allocated to Megapot tickets. Uses:

- **BuybackBurner funding.** Governance calls `transferToBuyback()` to send reserve USDC to the BuybackBurner. This is a manual governance action, not automatic.
- **Governance withdrawals.** Governance can withdraw via `withdraw()`. Requires a governance address to be set (TimelockController or Governor).

The reserve cannot be withdrawn by the owner or creator. Only a governance contract can move reserve funds.

## BuybackBurner

A Dutch auction that lets LP holders sell their LOTTERY/USDC LP tokens to the protocol in exchange for USDC. The protocol then burns the LP tokens permanently.

### How It Works

1. **Governance funds it.** Calls `transferToBuyback()` on treasury, sending USDC to BuybackBurner.
2. **Auction starts.** Price starts high, decays linearly to 0 over the epoch period.
3. **LP holders sell.** They call `buy()` with their LP tokens and receive USDC at the current auction price.
4. **LP is burned.** Sent to `0x000...dEaD`, permanently removed from supply.
5. **Price resets.** New epoch starts at 1.2x the purchase price.

### Why Participate?

LP holders get USDC for their LP tokens at a price set by the Dutch auction. If they wait for the price to decay to a favorable rate, they receive more USDC per LP token than they might on the open market.

### Auction Parameters

| Parameter | Default | Configurable |
|-----------|---------|-------------|
| Epoch duration | 24 hours | Yes (owner) |
| Price multiplier after purchase | 1.2x | Yes (owner) |
| Minimum init price | Floor value | Yes (owner) |

### Why Burn LP?

Burning LP tokens permanently removes them from circulation. The underlying LOTTERY and USDC reserves stay locked in the Uniswap pool, but fewer LP tokens exist to claim them. This creates a deflationary effect on LP supply.

### Protection

- **epochId** must match current epoch (prevents frontrunning)
- **deadline** for transaction expiry
- **maxUsdcExpected** for slippage protection
