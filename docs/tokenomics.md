# Tokenomics

## $LOTTERY Token

| Property | Value |
|----------|-------|
| Name | LOTTERY |
| Symbol | LOTTERY |
| Decimals | 18 |
| Max Supply | 100,000,000 (100M) |
| Chain | Base |

## Distribution

| Allocation | Amount | Percentage |
|------------|--------|------------|
| Emissions to Kings | 95,000,000 | 95% |
| Initial LP | 5,000,000 | 5% |

**No team allocation. No VC allocation. No airdrop.**

All tokens except the LP premine are earned through gameplay.

## King Income Streams

Being King earns you income in both $LOTTERY and USDC:

### 1. $LOTTERY Emissions
- **Rate:** 1 token/second
- **Cap:** 7 days per reign (604,800 tokens max)
- **Paid in:** $LOTTERY
- **Note:** Emissions stop permanently once 100M max supply is reached

### 2. USDC Referral Fees
- **Source:** Megapot referral fees from treasury ticket purchases
- **Split:** 50% to King, 50% to treasury
- **Paid in:** USDC
- **Harvested via:** Permissionless `harvest()` call on ReferralCollector

### 3. Dethrone Payout (on exit)
- **Source:** Next bidder's USDC
- **Amount:** 20-80% of the new bid (decays with reign duration)
- **Paid in:** USDC

## USDC Flow

Every bid creates USDC flows throughout the system:

| Recipient | Share | Source |
|-----------|-------|--------|
| Previous King | 20-80% | Direct from bid |
| Creator | 5% | Direct from bid |
| Treasury | 15-75% (residual) | Direct from bid |
| Megapot tickets | ~67% of treasury (configurable) | Treasury auto-purchase |
| Treasury reserve | ~33% of treasury (configurable) | Treasury retention |
| King (referral) | 50% of referral fees | ReferralCollector |
| Treasury (referral) | 50% of referral fees | ReferralCollector |

## Emission Schedule

- **Rate:** 1 token/second
- **Per King cap:** 7 days (604,800 tokens max per reign)
- **Total time to emit 95M:** ~3 years at continuous max rate

In practice, emissions slow as:
- Kings get dethroned before 7 days
- Time between Kings when no one is playing

## Liquidity

Initial liquidity on Uniswap V2:
- **5,000,000 LOTTERY** (5% premine minted directly to LP pair via one-time `premineForLP()`)
- **1,000 USDC**
- **Initial price:** $0.0002 per LOTTERY

The BuybackBurner can permanently reduce LP supply over time by buying and burning LP tokens using treasury reserve USDC. See [Treasury & Buyback](treasury.md) for details.

## Token Utility

$LOTTERY is a pure game token:
- Earned by being King
- Tradeable on Uniswap V2 (LOTTERY/USDC pair)
- Governance-ready (ERC20Votes) — no governance contracts deployed yet

Future governance may control:
- Treasury reserve withdrawals
- Megapot allocation percentage
- BuybackBurner funding
