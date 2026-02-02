# Smart Contracts

## Contract Addresses

### Base Sepolia (Testnet)

| Contract | Address |
|----------|---------|
| LotteryToken | `0x10117dF540d74A9595Fa08F56426bb3C28FF22c9` |
| LotteryMiner | `0xAFD683F33cBdC83790BCf73eA6D44582eB9d935F` |
| LotteryTreasury | `0xDB689D685F34A6335Ae12b042953fC9f9db73003` |
| BuybackBurner | `0x035b0cE12bAA3cF4A32C8AC467f7A70Cb38894Aa` |
| LP Pair | `0x49b04ED2133e6aA890650542b8C03b5426E844f0` |
| MockUSDC | `0x17e0491422685c309bFB6aDAF662c2832b41eF4E` |

### Base Mainnet

*Not yet deployed.*

## Contract Overview

### LotteryToken
ERC20 token with:
- 100M max supply
- Minting restricted to LotteryMiner
- ERC20Votes for governance
- ERC20Permit for gasless approvals
- 5M premine for initial LP

### LotteryMiner
Core game contract:
- Handles dethrone bids (`mine` function)
- Tracks current King and emissions
- Distributes bid fees (prev king, treasury, creator)
- Mints tokens on dethrone or claim
- Pausable by creator (max 7 days)

### LotteryTreasury
Fee management:
- Receives 15% of all bids
- Splits between Megapot tickets and reserve
- Governance-controlled withdrawals
- Funds BuybackBurner

### BuybackBurner
LP buyback mechanism:
- Dutch auction selling USDC for LP tokens
- Burns LP to 0xdead address
- Reduces LP supply over time
- Funded by treasury reserve

## Security

### Audits
- **Slither:** No critical issues found
- **Test coverage:** 108/108 tests passing
- **Invariant fuzzing:** Included in test suite

### Security Features
- ReentrancyGuard on all state-changing functions
- CEI (Checks-Effects-Interactions) pattern
- SafeERC20 for token transfers
- MEV protection (epochId + deadline)
- Emergency pause with 7-day auto-unpause
- Ownable2Step for admin functions

## Source Code

Contracts are located in the repository under `contracts/src/`:
- `LotteryToken.sol`
- `LotteryMiner.sol`
- `LotteryTreasury.sol`
- `BuybackBurner.sol`
- `MegapotRouter.sol`
- `ReferralCollector.sol`
