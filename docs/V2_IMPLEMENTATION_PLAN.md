# V2 Implementation Plan

**Status: Complete.** All changes deployed to Base mainnet.

## What was implemented

### Phase 1: Liveness Loop
- 3-phase price decay: 2x→1.1x (1h), 1.1x→$10 (24h), $10 floor
- Time-decaying payout: 80% (0-1h) → 60% (6h) → 20% (24h+)

### Phase 2: Cashflow Loop
- MegapotRouter: routes ticket purchases with referral set to ReferralCollector
- ReferralCollector: harvests referral fees, splits 50% King / 50% Treasury
- Auto-harvest on mine() and claimEmissions()

See [game-mechanics.md](game-mechanics.md) and [contracts.md](contracts.md) for current details.
