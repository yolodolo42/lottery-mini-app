# FAQ

## Gameplay

### How do I become King?
Click "Dethrone" and confirm the transaction. You need USDC on Base and a small amount of ETH for gas.

### What's the minimum bid?
$10 USDC. The actual minimum may be higher depending on the current price decay.

### How much do I earn as King?
1 $LOTTERY token per second, up to 7 days maximum (604,800 tokens).

### When should I claim emissions?
Anytime while King. If you're dethroned, emissions are auto-claimed. Claim before 7 days to avoid hitting the cap.

### Why did I only get 20% payout when dethroned?
Payout decreases with reign duration. Hold for 24+ hours = 20%. Get dethroned within 1 hour = 80%.

## Technical

### What wallet do I need?
Any wallet that supports Farcaster auth. Warpcast is recommended.

### What network is this on?
Base (Ethereum L2).

### Why did my transaction fail?
Common reasons:
- **"InvalidEpochId"**: Someone else bid first. Refresh and try again.
- **"BidTooLow"**: Price decayed. Your bid is now above minimum, refresh for current price.
- **"DeadlinePassed"**: Transaction took too long. Try again with fresh deadline.

### Is there MEV protection?
Yes. Transactions use epochId (must match current) and deadline (transaction expiry) to prevent frontrunning.

## Tokens

### Where can I trade $LOTTERY?
Uniswap V2 on Base. The LP pair is LOTTERY/USDC.

### What's the token supply?
100M max. 95% via emissions, 5% initial LP.

### Is there a team allocation?
No. All tokens except LP premine are earned through gameplay.

## Treasury

### What happens to treasury funds?
- Buys Megapot lottery tickets (configurable %)
- Reserve for governance-approved uses
- Can fund BuybackBurner for LP burns

### What is BuybackBurner?
A Dutch auction that uses USDC to buy LP tokens from holders, then burns them. This permanently reduces LP supply.

## Security

### Has the code been audited?
Slither analysis completed with no critical issues. Full test coverage with invariant fuzzing.

### Can the creator steal funds?
No. Creator can only:
- Pause/unpause (max 7 days)
- Receive 5% creator fee

Treasury withdrawals require governance approval.

### What if the game gets paused?
Max pause is 7 days, then auto-unpauses. This prevents permanent freeze.
