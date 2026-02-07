# Smart Contracts

## Contract Addresses

### Base Sepolia (Testnet)

| Contract | Address |
|----------|---------|
| LotteryToken | `0x10117dF540d74A9595Fa08F56426bb3C28FF22c9` |
| LotteryMiner | `0xAFD683F33cBdC83790BCf73eA6D44582eB9d935F` |
| LotteryTreasury | `0xDB689D685F34A6335Ae12b042953fC9f9db73003` |
| BuybackBurner | `0x035b0cE12bAA3cF4A32C8AC467f7A70Cb38894Aa` |
| MegapotRouter | `0xd820D03ace8E62cAE633Aa5A2a75786BFC65AA8e` |
| ReferralCollector | `0x7987dEbcA51e70e702f969046D8115540c59ff4B` |
| LP Pair | `0x49b04ED2133e6aA890650542b8C03b5426E844f0` |
| MockUSDC | `0x17e0491422685c309bFB6aDAF662c2832b41eF4E` |

### Base Mainnet

*Not yet deployed.*

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
- Mints $LOTTERY on dethrone or claim. If max supply is reached, mint fails silently — USDC payout still proceeds.
- Pausable by creator (max 7 days, auto-unpauses). Pause only blocks new bids — claiming emissions is always available.

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
- `harvest()` is permissionless — anyone can trigger distribution
- If no King, 100% goes to treasury

### BuybackBurner
LP buyback and burn:
- Dutch auction: LP holders sell LP tokens to the contract, receive USDC
- Burns received LP tokens to `0x000...dEaD`
- Funded by governance transferring USDC from treasury reserve
- See [Treasury & Buyback](treasury.md) for full details

## Security

### Audits
- **Slither:** No critical issues found
- **Test coverage:** 108/108 tests passing
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
