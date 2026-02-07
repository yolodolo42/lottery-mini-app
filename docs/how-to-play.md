# How to Play

## Connecting Your Wallet

LOTTERY uses Farcaster authentication via Warpcast. Click "Connect" and sign in with your Farcaster account.

You need:
- A Farcaster account
- USDC on Base network
- Small amount of ETH for gas

## Becoming the King

1. Check the **current bid price** displayed on the UI
2. Click **"Dethrone"** (or "Approve & Dethrone" if first time)
3. Confirm the transaction in your wallet
4. You are now the King

The minimum bid is $10 USDC. After a bid, the price starts at 2x and decays over 24 hours. The frontend batches the USDC approval and bid into a single transaction using EIP-5792 (with sequential fallback for wallets that don't support batching).

## Earning Emissions

While you are King:
- Earn **1 $LOTTERY token per second**
- Emissions cap at **7 days** (604,800 tokens max per reign)
- Track your pending emissions in the UI

Note: If the 100M max supply is reached, emission mints will fail silently. You still receive your USDC payout when dethroned, but no new $LOTTERY tokens are minted.

## Referral Fees

While you are King, you also earn **50% of Megapot referral fees** in USDC.

Every bid sends a portion to the treasury. The treasury auto-buys Megapot lottery tickets via the MegapotRouter. Megapot pays referral fees on those ticket purchases back to the ReferralCollector. The ReferralCollector splits them: **50% to the current King, 50% to treasury.**

Anyone can trigger the `harvest()` function on the ReferralCollector to distribute pending referral fees. It's permissionless.

## Claiming Rewards

**As current King:**
- Click "Claim" to collect pending $LOTTERY emissions
- Your emission timer resets but you stay King (your reign display time does not reset)
- Claim as often as you want

**When dethroned:**
- Emissions are automatically sent to you
- Receive your USDC payout from the new bid (20-80%)
- No action needed

## Tips

- **Dethrone quickly** for maximum payout (80% within first hour)
- **Wait for decay** if the current price is too high
- **Claim before 7 days** to avoid hitting emission cap
- **Harvest referral fees** while you're King for bonus USDC income
