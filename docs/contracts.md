# Smart Contracts

## Contract Addresses

### Base Mainnet

| Contract | Address |
|----------|---------|
| LotteryToken | [`0x07911ee281161f498Ae86acBad93F397ba35E0D3`](https://basescan.org/address/0x07911ee281161f498Ae86acBad93F397ba35E0D3) |
| LotteryMiner | [`0xd1DA10c6179693F05d15D420f5FE49405Da8a52B`](https://basescan.org/address/0xd1DA10c6179693F05d15D420f5FE49405Da8a52B) |
| LotteryTreasury | [`0xa680443Bc34E65D1fBaA0BF47ebEc5EF4f370E04`](https://basescan.org/address/0xa680443Bc34E65D1fBaA0BF47ebEc5EF4f370E04) |
| MegapotRouter | [`0xDD577b9663fCb8235e9476DCc1A3C2E6CC8c9d87`](https://basescan.org/address/0xDD577b9663fCb8235e9476DCc1A3C2E6CC8c9d87) |
| ReferralCollector | [`0x45C666A3f7bCE2CF5c346422b0d46EC50987A062`](https://basescan.org/address/0x45C666A3f7bCE2CF5c346422b0d46EC50987A062) |
| BuybackBurner | [`0x341f4295Cec19950D3ba441Dc4C45bD06d13AB5d`](https://basescan.org/address/0x341f4295Cec19950D3ba441Dc4C45bD06d13AB5d) |
| LP Pair | [`0x6e6Da38161E0d345d82C4F3aFC370087bF8F2a23`](https://basescan.org/address/0x6e6Da38161E0d345d82C4F3aFC370087bF8F2a23) |
| USDC | [`0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`](https://basescan.org/address/0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913) |
| Megapot | [`0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95`](https://basescan.org/address/0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95) |

## Contract Overview

### LotteryToken
ERC20 token with:
- 100M max supply hard cap
- Minting restricted to LotteryMiner (set once via `setMiner()`, cannot be changed)
- ERC20Votes for future governance
- ERC20Permit for gasless approvals
- 5M premine minted directly to LP pair via one-time `premineForLP()`

### LotteryMiner
Core game contract:
- Handles dethrone bids (`mine()`)
- Tracks current King and emissions
- Distributes bid fees: previous king (20-80%), creator (5%), treasury (residual)
- Mints $LOTTERY on dethrone or claim. If max supply is reached, mint fails silently but the USDC payout still proceeds.
- Pausable by creator (max 7 days, auto-unpauses). Pause only blocks new bids. Claiming emissions is always available.

### LotteryTreasury
Fee management:
- Receives the residual from each bid (15-75%)
- Splits deposits between Megapot tickets and reserve (configurable ratio)
- Auto-purchases Megapot tickets via MegapotRouter on every deposit
- If ticket purchase fails, USDC stays in Megapot pool and retries next deposit
- Governance can rescue stuck Megapot pool via `rescueMegapotPool()`
- Governance can fund BuybackBurner via `transferToBuyback()`
- Governance can withdraw reserve via `withdraw()`
- MegapotRouter set once via `setMegapotRouter()` (cannot be changed)
- BuybackBurner set once via `setBuybackBurner()` (cannot be changed)

### MegapotRouter
Referral fee capture:
- Routes Megapot ticket purchases from treasury
- Sets referral address to ReferralCollector on every purchase
- Ticket price: 1 USDC per ticket

### ReferralCollector
Referral fee distribution:
- Collects Megapot referral fees
- Splits 50/50 between current King (USDC) and treasury
- Auto-harvested on mine() and claimEmissions() via LotteryMiner.
- If no King, 100% goes to treasury

### BuybackBurner
LP buyback and burn:
- Dutch auction: LP holders sell LP tokens to the contract, receive USDC
- Burns received LP tokens to `0x000...dEaD`
- Funded by governance transferring USDC from treasury reserve
- See [Treasury & Buyback](treasury.md) for full details

## Security

### Audits
- **Audit:** No critical/high issues found
- **Test coverage:** 131 tests passing (unit + fork)
- **Invariant fuzzing:** Included in test suite

### Security Features
- ReentrancyGuard on LotteryMiner, LotteryTreasury, ReferralCollector, and BuybackBurner
- CEI (Checks-Effects-Interactions) pattern throughout
- SafeERC20 for all token transfers
- MEV protection via epochId + deadline on bids and buybacks
- Emergency pause with 7-day auto-unpause (LotteryMiner only)
- Ownable2Step on LotteryTreasury and BuybackBurner (two-step ownership transfer)
- Immutable creator address on LotteryMiner
- One-time setters: `setMiner()`, `setMegapotRouter()`, `setBuybackBurner()` cannot be changed after initial configuration

## Source Code

Contracts are located in the repository under `contracts/src/`:
- `LotteryToken.sol`
- `LotteryMiner.sol`
- `LotteryTreasury.sol`
- `BuybackBurner.sol`
- `MegapotRouter.sol`
- `ReferralCollector.sol`
