# FAQ

## Gameplay

### How do I become King?
Click "Dethrone" and confirm the transaction. You need USDC on Base and a small amount of ETH for gas. The frontend batches the USDC approval and bid into a single transaction.

### What's the minimum bid?
$10 USDC. The actual minimum may be higher depending on the current price decay.

### How much do I earn as King?
Two income streams:
1. **$LOTTERY tokens:** 1 per second, up to 7 days max (604,800 tokens)
2. **USDC:** 50% of Megapot referral fees (via `harvest()`)

### When should I claim emissions?
Anytime while King. If you're dethroned, emissions are auto-claimed. Claim before 7 days to avoid hitting the cap.

### Why did I only get 20% payout when dethroned?
Payout decreases with reign duration. Hold for 24+ hours = 20%. Get dethroned within 1 hour = 80%.

### What happens when the 100M token supply runs out?
Emissions stop. When dethroned, you still receive your USDC payout, but no new $LOTTERY tokens are minted. The contract handles this gracefully.

## Megapot & Referral Fees

### What is Megapot?
Megapot is a decentralized lottery on Base. The LOTTERY treasury auto-buys Megapot tickets with a portion of every bid, giving the protocol a shot at the jackpot.

### How do referral fees work?
When the treasury buys Megapot tickets, the purchase is routed through MegapotRouter with a referral set to the ReferralCollector. Megapot pays referral fees on these purchases. The ReferralCollector splits them: 50% to the current King, 50% back to treasury.

### How do I collect referral fees?
Call `harvest()` on the ReferralCollector contract. It's permissionless, so anyone can trigger it. The current King automatically receives their 50% share in USDC.

### What if Megapot is down?
If the ticket purchase fails, USDC stays in the treasury's Megapot pool and retries on the next deposit. If Megapot becomes permanently unavailable, governance can rescue stuck funds via `rescueMegapotPool()`.

### Why does this matter?
It creates a cashflow loop. More bids → more Megapot tickets → more referral fees → more reasons to be King. The King earns $LOTTERY emissions *and* USDC referral income simultaneously.

## Treasury

### Where does treasury money come from?
The treasury receives whatever is left from each bid after paying the previous king and creator. That's between 15% and 75%, depending on how long the previous king held. If they were dethroned within 1 hour (80% payout), treasury gets 15%. If they held for 24+ hours (20% payout), treasury gets 75%.

### How is treasury split?
By default, ~67% of each deposit buys Megapot tickets and ~33% goes to the reserve pool. This ratio is configurable by the owner.

### What is BuybackBurner?
A Dutch auction where LP holders sell their LOTTERY/USDC LP tokens to the protocol for USDC. The protocol burns the LP tokens permanently, reducing LP supply. Governance must manually fund it by transferring USDC from the treasury reserve.

### Who controls treasury withdrawals?
Only a governance contract (once set). The owner and creator cannot withdraw from the reserve. Governance is not yet deployed.

## Technical

### What wallet do I need?
Any wallet that supports Farcaster auth. Warpcast is recommended.

### What network is this on?
Base (Ethereum L2).

### Why did my transaction fail?
Common reasons:
- **"InvalidEpochId"**: Someone else bid first. Refresh and try again.
- **"BidTooLow"**: Price changed. Refresh for current price.
- **"DeadlinePassed"**: Transaction took too long. Try again.

### Is there MEV protection?
Yes. Transactions use epochId (must match current) and deadline (transaction expiry) to prevent frontrunning.

### Can I still claim emissions when the game is paused?
Yes. Pausing only blocks new bids. Claiming emissions is always available.

## Tokens

### Where can I trade $LOTTERY?
Uniswap V2 on Base. The LP pair is LOTTERY/USDC.

### What's the token supply?
100M max. 95% via emissions, 5% initial LP (minted directly to the LP pair).

### Is there a team allocation?
No. All tokens except LP premine are earned through gameplay. The creator receives 5% of each bid in USDC.

### Is there governance?
The $LOTTERY token has ERC20Votes built in, but no governance contracts are deployed yet. Future governance could control treasury reserve withdrawals, Megapot allocation, and BuybackBurner funding.

## Security

### Has the code been audited?
Audited with no critical issues. 131 tests passing (unit + fork + invariant fuzzing).

### Can the creator steal funds?
No. Creator can only:
- Pause/unpause bidding (max 7 days, auto-unpauses)
- Receive 5% creator fee from bids

Treasury withdrawals require governance approval. Key contract references (miner, router, buyback burner) are set once and cannot be changed.

### What if the game gets paused?
Max pause is 7 days, then auto-unpauses. Claiming emissions works even during pause.
