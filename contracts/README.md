# $LOTTERY Contracts

King-of-the-Hill DeFi game where users bid USDC to become King and earn $LOTTERY tokens.

---

## Contracts

| Contract | Purpose |
|----------|---------|
| **LotteryMiner** | Core game logic - Dutch auction bidding, emissions, MEV protection |
| **LotteryToken** | ERC20 with voting (ERC20Votes), 100M max supply |
| **LotteryTreasury** | Fee routing, Megapot tickets, buyback integration |
| **MegapotRouter** | Routes ticket purchases with referral fee capture |
| **ReferralCollector** | Distributes referral fees (50% King / 50% Treasury) |
| **BuybackBurner** | Dutch auction for LP buyback & burn (Phase 4) |

---

## Deployed Addresses (Base Mainnet)

| Contract | Address |
|----------|---------|
| LotteryToken | [`0x07911ee281161f498Ae86acBad93F397ba35E0D3`](https://basescan.org/address/0x07911ee281161f498Ae86acBad93F397ba35E0D3) |
| LotteryMiner | [`0xd1DA10c6179693F05d15D420f5FE49405Da8a52B`](https://basescan.org/address/0xd1DA10c6179693F05d15D420f5FE49405Da8a52B) |
| LotteryTreasury | [`0xa680443Bc34E65D1fBaA0BF47ebEc5EF4f370E04`](https://basescan.org/address/0xa680443Bc34E65D1fBaA0BF47ebEc5EF4f370E04) |
| MegapotRouter | [`0xDD577b9663fCb8235e9476DCc1A3C2E6CC8c9d87`](https://basescan.org/address/0xDD577b9663fCb8235e9476DCc1A3C2E6CC8c9d87) |
| ReferralCollector | [`0x45C666A3f7bCE2CF5c346422b0d46EC50987A062`](https://basescan.org/address/0x45C666A3f7bCE2CF5c346422b0d46EC50987A062) |
| BuybackBurner | [`0x341f4295Cec19950D3ba441Dc4C45bD06d13AB5d`](https://basescan.org/address/0x341f4295Cec19950D3ba441Dc4C45bD06d13AB5d) |
| LP Pair | [`0x6e6Da38161E0d345d82C4F3aFC370087bF8F2a23`](https://basescan.org/address/0x6e6Da38161E0d345d82C4F3aFC370087bF8F2a23) |

---

## Quick Start

### Build
```bash
forge build
```

### Test (131 tests)
```bash
forge test -vv
```

### Deploy
```bash
source ../.env
forge script deployments/DeployAll.s.sol:DeployAllScript \
  --rpc-url $BASE_RPC_URL --broadcast
```

See `deployments/README.md` for individual contract deployment.

---

## Architecture

### Game Mechanics

1. **Bidding:** User bids USDC to become King
2. **Emissions:** King earns 1 $LOTTERY/sec (max 7 days per reign)
3. **Price Decay:** Bid price decays in 3 phases (2x→1.1x→$1 over 24h)
4. **Payout Decay:** Previous king gets 80%→20% (time-decaying over 24h)

### Fee Distribution

On each bid:
- 20-80% → Previous King (time-decaying)
- 5% → Creator
- 15-75% → Treasury (residual)

Treasury splits:
- ~10% → Megapot tickets (auto-purchased)
- ~5% → Reserve (governance-controlled)

Reserve can be:
- Withdrawn by governance
- Transferred to BuybackBurner for LP auctions

---

## Security

- ✅ CEI pattern (Checks-Effects-Interactions)
- ✅ ReentrancyGuard on all stateful functions
- ✅ SafeERC20 for all transfers
- ✅ MEV protection (epochId + deadline)
- ✅ Graceful degradation (token cap)
- ✅ 7-day pause timeout (auto-unpause)
- ✅ Governance-gated treasury access

---

## Development

Built with Foundry. See: https://book.getfoundry.sh/

### Useful Commands

```bash
# Run specific test file
forge test --match-path test/BuybackBurner.t.sol

# Run tests matching pattern
forge test --match-test "PriceDecay"

# Gas snapshot
forge snapshot

# Format code
forge fmt

# Coverage
forge coverage
```

---

## Documentation

- `PROGRESS.md` - Project progress and status
- `docs/V2_IMPLEMENTATION_PLAN.md` - Phases 1 & 2 details
- `docs/PHASE_4_BUYBACK_PLAN.md` - BuybackBurner implementation
- `deployments/README.md` - Deployment guide
