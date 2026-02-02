# LOTTERY v2 Implementation Plan - Phase 1 + Phase 2

## Summary

Fix the game freeze by implementing:
1. **Phase 1:** 3-phase price decay + time-decaying prev-king payout
2. **Phase 2:** MegapotRouter + ReferralCollector for cashflow capture

---

## Phase 1: Liveness Loop

### Problem
- Price floors at 1.1x forever after 1 hour → game freezes
- 80% payout is fixed → incentivizes griefing with large bids

### Solution

**3-Phase Price Decay:**
| Phase | Time | Price |
|-------|------|-------|
| A | 0-1h | 2x → 1.1x (current) |
| B | 1h-24h | 1.1x → 1 USDC |
| C | >24h | 1 USDC (constant) |

**Time-Decaying Prev-King Payout:**
| Time | Payout |
|------|--------|
| ≤1h | 80% |
| 1h-6h | 80% → 60% |
| 6h-24h | 60% → 20% |
| >24h | 20% |

### Files to Modify

**`contracts/src/LotteryMiner.sol`**

1. Add constants (after line 29):
```solidity
uint256 public constant DECAY_PHASE_B = 24 hours;
uint256 public constant MIN_BID_ABS = 1e6; // 1 USDC

uint256 public constant PAYOUT_PHASE_1 = 1 hours;
uint256 public constant PAYOUT_PHASE_2 = 6 hours;
uint256 public constant PAYOUT_PHASE_3 = 24 hours;
uint256 public constant PREV_KING_BPS_MAX = 8000;
uint256 public constant PREV_KING_BPS_MID = 6000;
uint256 public constant PREV_KING_BPS_MIN = 2000;
```

2. Replace `getCurrentPrice()` (lines 162-175):
```solidity
function getCurrentPrice() public view returns (uint256) {
    if (lastBidAmount == 0) return 0;
    uint256 elapsed = block.timestamp - lastBidTime;

    // Phase A: 0-1h (2x → 1.1x)
    if (elapsed < DECAY_PERIOD) {
        uint256 startPrice = lastBidAmount * 2;
        uint256 endPrice = (lastBidAmount * 11000) / BPS_DENOMINATOR;
        return startPrice - ((startPrice - endPrice) * elapsed) / DECAY_PERIOD;
    }

    // Phase B: 1h-24h (1.1x → MIN_BID_ABS)
    if (elapsed < DECAY_PHASE_B) {
        uint256 startPrice = (lastBidAmount * 11000) / BPS_DENOMINATOR;
        if (startPrice <= MIN_BID_ABS) return MIN_BID_ABS;
        uint256 elapsedB = elapsed - DECAY_PERIOD;
        uint256 durationB = DECAY_PHASE_B - DECAY_PERIOD;
        return startPrice - ((startPrice - MIN_BID_ABS) * elapsedB) / durationB;
    }

    // Phase C: >24h (MIN_BID_ABS)
    return MIN_BID_ABS;
}
```

3. Replace `getMinimumBid()` (lines 177-184):
```solidity
function getMinimumBid() public view returns (uint256) {
    if (lastBidAmount == 0) return MIN_FIRST_BID;
    uint256 currentPrice = getCurrentPrice();
    return currentPrice > MIN_BID_ABS ? currentPrice : MIN_BID_ABS;
}
```

4. Add `_getPrevKingBps()` helper:
```solidity
function _getPrevKingBps() internal view returns (uint256) {
    uint256 elapsed = block.timestamp - lastBidTime;

    if (elapsed <= PAYOUT_PHASE_1) return PREV_KING_BPS_MAX;

    if (elapsed <= PAYOUT_PHASE_2) {
        uint256 e = elapsed - PAYOUT_PHASE_1;
        uint256 d = PAYOUT_PHASE_2 - PAYOUT_PHASE_1;
        return PREV_KING_BPS_MAX - ((PREV_KING_BPS_MAX - PREV_KING_BPS_MID) * e) / d;
    }

    if (elapsed <= PAYOUT_PHASE_3) {
        uint256 e = elapsed - PAYOUT_PHASE_2;
        uint256 d = PAYOUT_PHASE_3 - PAYOUT_PHASE_2;
        return PREV_KING_BPS_MID - ((PREV_KING_BPS_MID - PREV_KING_BPS_MIN) * e) / d;
    }

    return PREV_KING_BPS_MIN;
}
```

5. Modify `mine()` fee calculation (line 99):
```solidity
// Before: uint256 prevKingAmount = (bidAmount * PREV_KING_BPS) / BPS_DENOMINATOR;
// After:
uint256 prevKingBps = _getPrevKingBps();
uint256 prevKingAmount = (bidAmount * prevKingBps) / BPS_DENOMINATOR;
```

---

## Phase 2: Cashflow Loop

### Problem
- Treasury buys Megapot tickets with `referrer=address(0)`
- Megapot pays 10% referral fee... to nobody
- Free money left on table

### Solution

**New Contracts:**
1. `MegapotRouter` - Routes ticket purchases with referrer set
2. `ReferralCollector` - Collects and distributes referral fees

**Fee Distribution (no staking vault yet):**
- 50% → Current King
- 50% → Treasury

### New Contract: `contracts/src/MegapotRouter.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMegapot {
    function purchaseTickets(address referrer, uint256 value, address recipient) external returns (bool);
}

contract MegapotRouter {
    using SafeERC20 for IERC20;

    IERC20 public immutable usdc;
    IMegapot public immutable megapot;
    address public immutable referralCollector;

    error ZeroAddress();

    constructor(address _usdc, address _megapot, address _referralCollector) {
        if (_usdc == address(0) || _megapot == address(0) || _referralCollector == address(0)) revert ZeroAddress();
        usdc = IERC20(_usdc);
        megapot = IMegapot(_megapot);
        referralCollector = _referralCollector;
    }

    function purchaseTickets(uint256 value, address recipient) external returns (uint256) {
        usdc.safeTransferFrom(msg.sender, address(this), value);
        usdc.forceApprove(address(megapot), value);
        megapot.purchaseTickets(referralCollector, value, recipient);
        return value / 1e6;
    }
}
```

### New Contract: `contracts/src/ReferralCollector.sol`

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface IMegapotFees {
    function withdrawReferralFees() external;
    function referralFeesClaimable(address) external view returns (uint256);
}

interface ILotteryMiner {
    function king() external view returns (address);
}

contract ReferralCollector is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant KING_BPS = 5000;
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable usdc;
    IMegapotFees public immutable megapot;
    ILotteryMiner public immutable miner;
    address public immutable treasury;

    event Harvested(uint256 total, uint256 toKing, uint256 toTreasury);

    error ZeroAddress();
    error NothingToHarvest();

    constructor(address _usdc, address _megapot, address _miner, address _treasury) {
        if (_usdc == address(0) || _megapot == address(0) || _miner == address(0) || _treasury == address(0)) revert ZeroAddress();
        usdc = IERC20(_usdc);
        megapot = IMegapotFees(_megapot);
        miner = ILotteryMiner(_miner);
        treasury = _treasury;
    }

    function harvest() external nonReentrant {
        uint256 claimable = megapot.referralFeesClaimable(address(this));
        if (claimable == 0) revert NothingToHarvest();

        uint256 before = usdc.balanceOf(address(this));
        megapot.withdrawReferralFees();
        uint256 harvested = usdc.balanceOf(address(this)) - before;

        address king = miner.king();
        uint256 kingAmount = king != address(0) ? (harvested * KING_BPS) / BPS_DENOMINATOR : 0;
        uint256 treasuryAmount = harvested - kingAmount;

        if (kingAmount > 0) usdc.safeTransfer(king, kingAmount);
        usdc.safeTransfer(treasury, treasuryAmount);

        emit Harvested(harvested, kingAmount, treasuryAmount);
    }

    function pendingFees() external view returns (uint256) {
        return megapot.referralFeesClaimable(address(this));
    }
}
```

### Modify: `contracts/src/LotteryTreasury.sol`

1. Add interface and state:
```solidity
interface IMegapotRouter {
    function purchaseTickets(uint256 value, address recipient) external returns (uint256);
}

// Add to state variables
address public megapotRouter;

// Add error
error RouterAlreadySet();
```

2. Add setter (after setMiner):
```solidity
function setMegapotRouter(address _router) external onlyOwner {
    if (megapotRouter != address(0)) revert RouterAlreadySet();
    if (_router == address(0)) revert ZeroAddress();
    megapotRouter = _router;
}
```

3. Modify `_executePurchase()` (line 122):
```solidity
// Replace megapot.purchaseTickets(address(0), amount, address(0)); with:
if (megapotRouter != address(0)) {
    usdc.forceApprove(megapotRouter, amount);
    IMegapotRouter(megapotRouter).purchaseTickets(amount, address(0));
} else {
    usdc.forceApprove(address(megapot), amount);
    megapot.purchaseTickets(address(0), amount, address(0));
}
```

---

## Tests to Add

**`contracts/test/Lottery.t.sol`**

### Phase 1 Tests (~12)
```
test_PriceDecay_PhaseA_2xAt0
test_PriceDecay_PhaseA_1_1xAt1Hour
test_PriceDecay_PhaseB_MidwayAt12Hours
test_PriceDecay_PhaseB_MinBidAt24Hours
test_PriceDecay_PhaseC_ConstantAfter24Hours
test_MinimumBid_AfterFullDecay

test_PrevKingPayout_80PercentAt0
test_PrevKingPayout_80PercentAt1Hour
test_PrevKingPayout_70PercentAt3_5Hours
test_PrevKingPayout_60PercentAt6Hours
test_PrevKingPayout_40PercentAt15Hours
test_PrevKingPayout_20PercentAt24Hours
```

### Phase 2 Tests (~8)
```
test_Router_SetsReferrer
test_Router_TransfersUSDC
test_Collector_HarvestWithKing
test_Collector_HarvestNoKing_AllToTreasury
test_Collector_RevertsNothingToHarvest
test_Collector_PendingFeesView
test_Treasury_UsesRouterWhenSet
test_Treasury_FallbackWhenNoRouter
```

### Update MockMegapot
Add referral fee tracking:
```solidity
mapping(address => uint256) public referralFeesClaimable;

function purchaseTickets(address referrer, uint256 value, address) external returns (bool) {
    usdc.transferFrom(msg.sender, address(this), value);
    if (referrer != address(0)) {
        referralFeesClaimable[referrer] += (value * 1000) / 10000; // 10%
    }
    return true;
}

function withdrawReferralFees() external {
    uint256 amount = referralFeesClaimable[msg.sender];
    referralFeesClaimable[msg.sender] = 0;
    usdc.transfer(msg.sender, amount);
}
```

---

## Deployment Order

```
1. Deploy LotteryToken (fresh)
2. Deploy LotteryTreasury (fresh, with megapotRouter field)
3. Deploy LotteryMiner v2 (with new decay logic)
4. Deploy ReferralCollector
5. Deploy MegapotRouter
6. token.setMiner(miner)
7. treasury.setMiner(miner)
8. treasury.setMegapotRouter(router)
```

---

## Verification

```bash
# Run all tests
cd contracts && forge test -vv

# Run only Phase 1 tests
forge test --match-test "PriceDecay\|PrevKingPayout" -vv

# Run only Phase 2 tests
forge test --match-test "Router\|Collector" -vv

# Gas snapshot
forge snapshot
```

---

## Summary

| Change | File | Lines |
|--------|------|-------|
| New constants | LotteryMiner.sol | +10 |
| 3-phase price decay | LotteryMiner.sol | ~30 |
| Time-decaying payout | LotteryMiner.sol | ~25 |
| MegapotRouter | New file | ~30 |
| ReferralCollector | New file | ~50 |
| Treasury router integration | LotteryTreasury.sol | ~15 |
| Tests | Lottery.t.sol | ~200 |
| Mock update | Lottery.t.sol | ~15 |

**Total: ~375 lines of changes/additions**
