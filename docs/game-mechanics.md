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
- After 12 hours: ~$62
- After 24 hours: $10

The absolute minimum bid is **$10 USDC**.

## Payout to Previous King

When dethroned, the previous King receives a percentage of the new bid in USDC. This percentage decreases the longer they held the throne:

| Reign Duration | Payout % |
|----------------|----------|
| 0 - 1 hour | 80% |
| 1 - 6 hours | 80% → 60% (linear decay) |
| 6 - 24 hours | 60% → 20% (linear decay) |
| 24+ hours | 20% |

Quick dethroning is rewarded. If you hold for a long time, you've already earned more emissions.

## Fee Distribution

Every bid is split three ways:

| Recipient | Percentage |
|-----------|------------|
| Previous King | 20-80% (time-based decay) |
| Creator | 5% (fixed) |
| Treasury | Remainder (15-75%) |

Treasury receives the residual — whatever is left after the previous king and creator are paid. When the previous king gets 80%, treasury gets 15%. When the previous king gets 20%, treasury gets 75%.

On first bid (no previous King), the previous king's share goes to treasury instead. Treasury receives 95%, creator receives 5%.

## Megapot Integration

A configurable portion of each treasury deposit (default ~67%) automatically purchases **Megapot lottery tickets**. The remaining ~33% goes to the reserve pool. The owner can adjust this split from 0% to 100% via `setMegapotBps()`.

Ticket purchases are routed through the **MegapotRouter**, which sets the referral address to the **ReferralCollector** contract. Every ticket purchase generates referral fees that flow back into the LOTTERY ecosystem.

If the Megapot ticket purchase fails (e.g. Megapot is paused), the USDC stays in the Megapot pool and retries on the next deposit.

**The flow:**
```
Bid USDC → 15-75% to Treasury → Auto-buy Megapot tickets
                                        ↓
                                Megapot referral fees
                                        ↓
                              ReferralCollector contract
                                ↓               ↓
                          50% to King    50% to Treasury
```

## Referral Fee Distribution

Megapot pays referral fees on ticket purchases. The ReferralCollector splits them:

| Recipient | Share |
|-----------|-------|
| Current King | 50% |
| Treasury | 50% |

- `harvest()` is **permissionless** — anyone can call it
- If there's no King, 100% goes to treasury
- Fees are paid in USDC, not $LOTTERY

More bids → more tickets → more referral fees → more reasons to be King.

## Token Emissions

The current King earns $LOTTERY at a fixed rate:

- **Rate:** 1 token per second
- **Cap:** 7 days maximum (604,800 tokens)
- **Claiming:** Manual claim anytime, or auto-paid on dethrone
- **Max supply:** Once 100M tokens are minted, emissions stop. The contract catches the mint failure and proceeds normally — the king still receives their USDC payout but no new tokens.

Emissions reset when you claim. If you claim after 3 days, then wait 4 more days as King, you can claim again.

## MEV Protection

Transactions include:
- **epochId:** Must match current epoch (prevents frontrunning)
- **deadline:** Transaction expires after timestamp

This prevents sandwich attacks and frontrunning on dethrone bids.
