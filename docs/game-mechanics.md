# Game Mechanics

## Bidding (Dutch Auction)

The bid price decays over time using a Dutch auction:

| Time Since Last Bid | Price Multiplier |
|---------------------|------------------|
| 0 - 1 hour | 2x → 1.1x (linear decay) |
| 1 - 24 hours | 1.1x → $10 min (linear decay) |
| 24+ hours | $10 minimum |

**Example:** If someone bid $100 USDC:
- Immediately after: ~$200
- After 1 hour: ~$110
- After 12 hours: ~$55
- After 24 hours: $10

The absolute minimum bid is **$10 USDC**.

## Payout to Previous King

When dethroned, the previous King receives a percentage of the new bid. This percentage decreases the longer they held the throne:

| Reign Duration | Payout % |
|----------------|----------|
| 0 - 1 hour | 80% |
| 1 - 6 hours | 80% → 60% (linear decay) |
| 6 - 24 hours | 60% → 20% (linear decay) |
| 24+ hours | 20% |

**Rationale:** Quick dethroning is rewarded. If you hold for a long time, you've already earned more emissions.

## Fee Distribution

Every bid is split:

| Recipient | Percentage |
|-----------|------------|
| Previous King | 20-80% (time-based) |
| Treasury | 15% |
| Creator | 5% |

On first bid (no previous King), the 80% goes to treasury instead.

## Token Emissions

The current King earns $LOTTERY at a fixed rate:

- **Rate:** 1 token per second
- **Cap:** 7 days maximum (604,800 tokens)
- **Claiming:** Manual claim anytime, or auto-paid on dethrone

Emissions reset when you claim. If you claim after 3 days, then wait 4 more days as King, you can claim again.

## MEV Protection

Transactions include:
- **epochId:** Must match current epoch (prevents frontrunning)
- **deadline:** Transaction expires after timestamp

This prevents sandwich attacks and frontrunning on dethrone bids.
