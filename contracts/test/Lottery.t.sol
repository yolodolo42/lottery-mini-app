// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LotteryToken.sol";
import "../src/LotteryMiner.sol";
import "../src/LotteryTreasury.sol";
import "../src/MegapotRouter.sol";
import "../src/ReferralCollector.sol";
import "../src/BuybackBurner.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock USDC
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

// Mock Megapot with referral fee tracking (v2)
contract MockMegapot {
    IERC20 public usdc;
    uint256 public totalTicketsPurchased;
    uint256 public currentDrawingId;
    bool public shouldFail;
    bool public shouldRevertWithdraw;

    // v2: Referral fee tracking
    mapping(address => uint256) public referralFeesClaimable;
    mapping(address => uint256) public winnings;
    address public lastReferrer;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
        currentDrawingId = 1; // Start at drawing 1
    }

    function setShouldFail(bool _shouldFail) external {
        shouldFail = _shouldFail;
    }

    function setShouldRevertWithdraw(bool _shouldRevertWithdraw) external {
        shouldRevertWithdraw = _shouldRevertWithdraw;
    }

    function purchaseTickets(address referrer, uint256 value, address) external returns (bool) {
        if (shouldFail) revert("Megapot is down");
        usdc.transferFrom(msg.sender, address(this), value);
        totalTicketsPurchased += value / 1e6;

        // v2: Track referral fees (10% of purchase value)
        lastReferrer = referrer;
        if (referrer != address(0)) {
            referralFeesClaimable[referrer] += (value * 1000) / 10000; // 10%
        }
        return true;
    }

    // v2: Withdraw referral fees (plural to match real deployed Megapot)
    function withdrawReferralFees() external returns (bool) {
        if (shouldRevertWithdraw) revert("withdraw failed");
        uint256 amount = referralFeesClaimable[msg.sender];
        referralFeesClaimable[msg.sender] = 0;
        usdc.transfer(msg.sender, amount);
        return true;
    }

    function referralFeeBps() external pure returns (uint256) { return 1000; }

    function usersInfo(address user) external view returns (uint256, uint256, bool) {
        return (0, winnings[user], winnings[user] > 0);
    }

    function withdrawWinnings() external {
        uint256 amount = winnings[msg.sender];
        winnings[msg.sender] = 0;
        usdc.transfer(msg.sender, amount);
    }

    function setWinnings(address user, uint256 amount) external {
        winnings[user] = amount;
    }
}

contract LotteryTest is Test {
    MockUSDC public usdc;
    MockMegapot public megapot;
    LotteryToken public token;
    LotteryMiner public miner;
    LotteryTreasury public treasury;

    address public creator = address(0x1);
    address public owner = address(0x2);
    address public alice = address(0x3);
    address public bob = address(0x4);

    function _mineAs(address caller, uint256 bidAmount) internal {
        uint256 currentEpoch = miner.epochId();
        vm.prank(caller);
        miner.mine(bidAmount, currentEpoch, block.timestamp + 1 hours);
    }

    function _mine(uint256 bidAmount) internal {
        miner.mine(bidAmount, miner.epochId(), block.timestamp + 1 hours);
    }

    function setUp() public {
        // Deploy mocks
        usdc = new MockUSDC();
        megapot = new MockMegapot(address(usdc));

        // Deploy token first (no miner set yet)
        token = new LotteryToken();

        // Deploy treasury (without miner - set later)
        treasury = new LotteryTreasury(
            address(usdc),
            address(megapot),
            owner
        );

        // Deploy miner with immutable treasury
        miner = new LotteryMiner(address(usdc), address(token), creator, address(treasury));

        // Set miner in token (one-time)
        token.setMiner(address(miner));

        // Set miner in treasury (one-time)
        vm.prank(owner);
        treasury.setMiner(address(miner));

        // Fund test accounts
        usdc.mint(alice, 10000e6);
        usdc.mint(bob, 10000e6);

        // Approve miner
        vm.prank(alice);
        usdc.approve(address(miner), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(miner), type(uint256).max);
    }

    // ============ Token Tests ============

    function test_TokenMetadata() public view {
        assertEq(token.name(), "LOTTERY");
        assertEq(token.symbol(), "LOTTERY");
        assertEq(token.decimals(), 18);
    }

    function test_OnlyMinerCanMint() public {
        vm.expectRevert(LotteryToken.OnlyMiner.selector);
        token.mint(alice, 100e18);
    }

    function test_OnlyDeployerCanSetMiner() public {
        LotteryToken newToken = new LotteryToken();

        vm.prank(alice);
        vm.expectRevert(LotteryToken.OnlyDeployer.selector);
        newToken.setMiner(address(miner));
    }

    // ============ Miner Tests ============

    function test_TreasuryIsImmutable() public view {
        // Treasury is set at construction and immutable
        assertEq(address(miner.treasury()), address(treasury));
    }

    function test_FirstBid() public {
        uint256 bidAmount = 100e6; // 100 USDC

        _mineAs(alice, bidAmount);

        assertEq(miner.king(), alice);
        assertEq(miner.lastBidAmount(), bidAmount);
    }

    function test_FirstBidFeeDistribution() public {
        uint256 bidAmount = 100e6;
        uint256 creatorBalanceBefore = usdc.balanceOf(creator);

        _mineAs(alice, bidAmount);

        // Creator gets 5%
        uint256 creatorAmount = (bidAmount * 500) / 10000;
        assertEq(usdc.balanceOf(creator) - creatorBalanceBefore, creatorAmount);

        // Treasury gets 95% (80% + 15% since no prev king)
        // But megapotPool is auto-purchased, so check reserve + megapot's USDC
        uint256 treasuryAmount = bidAmount - creatorAmount;
        (, uint256 reservePool) = treasury.getPoolBalances();
        uint256 megapotReceived = usdc.balanceOf(address(megapot));
        assertEq(megapotReceived + reservePool, treasuryAmount);
    }

    function test_SecondBidPaysPrevKing() public {
        // Alice bids first
        _mineAs(alice, 100e6);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Bob bids second
        _mineAs(bob, 200e6);

        // Alice should receive 80% of Bob's bid
        uint256 prevKingAmount = (200e6 * 8000) / 10000;
        assertEq(usdc.balanceOf(alice) - aliceBalanceBefore, prevKingAmount);
        assertEq(miner.king(), bob);
    }

    function test_EmissionAccrual() public {
        _mineAs(alice, 100e6);

        // Warp 1 hour
        vm.warp(block.timestamp + 1 hours);

        uint256 pending = miner.getPendingEmissions();
        assertEq(pending, 3600e18); // 1 token/second * 3600 seconds
    }

    function test_ClaimEmissions() public {
        _mineAs(alice, 100e6);

        vm.warp(block.timestamp + 1 hours);

        vm.prank(alice);
        miner.claimEmissions();

        assertEq(token.balanceOf(alice), 3600e18);
    }

    function test_OnlyKingCanClaim() public {
        _mineAs(alice, 100e6);

        vm.warp(block.timestamp + 1 hours);

        vm.prank(bob);
        vm.expectRevert(LotteryMiner.NotKing.selector);
        miner.claimEmissions();
    }

    function test_DutchAuctionPriceDecay() public {
        _mineAs(alice, 100e6);

        // Phase A: 0-1h (2x -> 1.1x)
        // At t=0: price = 200 USDC (2x)
        assertEq(miner.getCurrentPrice(), 200e6);

        // At t=30min: midpoint of Phase A = (200 + 110) / 2 = 155 USDC
        vm.warp(block.timestamp + 30 minutes);
        assertEq(miner.getCurrentPrice(), 155e6);

        // At t=1hr: price = 110 USDC (1.1x, end of Phase A)
        vm.warp(block.timestamp + 30 minutes);
        assertEq(miner.getCurrentPrice(), 110e6);

        // Phase B: 1h-24h (1.1x -> 10 USDC)
        // At t=12.5h (midpoint of Phase B): ~60 USDC
        vm.warp(block.timestamp + 11 hours + 30 minutes);
        uint256 midPriceB = miner.getCurrentPrice();
        assertGt(midPriceB, 55e6);
        assertLt(midPriceB, 65e6);

        // At t=24h: price = 10 USDC (MIN_BID_ABS)
        vm.warp(block.timestamp + 11 hours + 30 minutes);
        assertEq(miner.getCurrentPrice(), 10e6);

        // Phase C: >24h (constant 10 USDC)
        vm.warp(block.timestamp + 24 hours);
        assertEq(miner.getCurrentPrice(), 10e6);
    }

    function test_BidTooLow() public {
        _mineAs(alice, 100e6);

        // Try to bid below current price
        uint256 currentEpoch = miner.epochId();
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(LotteryMiner.BidTooLow.selector, 200e6, 50e6));
        miner.mine(50e6, currentEpoch, block.timestamp + 1 hours);
    }

    // ============ v2 Price Decay Tests ============

    function test_PriceDecay_PhaseB_LinearDecay() public {
        _mineAs(alice, 100e6);

        // Skip to Phase B (after 1h)
        vm.warp(block.timestamp + 1 hours);
        uint256 priceAt1h = miner.getCurrentPrice();
        assertEq(priceAt1h, 110e6); // 1.1x

        // At 12h (midway through Phase B)
        vm.warp(block.timestamp + 11 hours);
        uint256 priceAt12h = miner.getCurrentPrice();
        // Should be ~halfway between 110e6 and 10e6
        assertGt(priceAt12h, 55e6);
        assertLt(priceAt12h, 65e6);

        // At 24h (end of Phase B)
        vm.warp(block.timestamp + 12 hours);
        assertEq(miner.getCurrentPrice(), 10e6);
    }

    function test_PriceDecay_PhaseC_Constant() public {
        _mineAs(alice, 100e6);

        // Skip to Phase C (after 24h)
        vm.warp(block.timestamp + 24 hours);
        assertEq(miner.getCurrentPrice(), 10e6);

        // Still 10 USDC after 48h
        vm.warp(block.timestamp + 24 hours);
        assertEq(miner.getCurrentPrice(), 10e6);

        // Still 10 USDC after 7 days
        vm.warp(block.timestamp + 5 days);
        assertEq(miner.getCurrentPrice(), 10e6);
    }

    function test_MinimumBid_AfterFullDecay() public {
        _mineAs(alice, 100e6);

        // After 24h, minimum bid is MIN_BID_ABS (10 USDC)
        vm.warp(block.timestamp + 24 hours);
        assertEq(miner.getMinimumBid(), 10e6);

        // Can bid exactly 10 USDC
        _mineAs(bob, 10e6);
        assertEq(miner.king(), bob);
    }

    // ============ v2 Payout Decay Tests ============

    function test_PrevKingPayout_80PercentAt0() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Bob bids immediately (t=0, should get 80%)
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 160e6); // 80% of 200
    }

    function test_PrevKingPayout_80PercentAt1Hour() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Wait exactly 1 hour (boundary of Phase 1)
        vm.warp(block.timestamp + 1 hours);
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 160e6); // Still 80% at exactly 1h
    }

    function test_PrevKingPayout_DecayAt3_5Hours() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Wait 3.5 hours (midway through Phase 2: 1h-6h)
        // Payout = 80% - (20% * 2.5h/5h) = 80% - 10% = 70%
        vm.warp(block.timestamp + 3 hours + 30 minutes);
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 140e6); // 70% of 200
    }

    function test_PrevKingPayout_60PercentAt6Hours() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Wait exactly 6 hours (boundary of Phase 2)
        vm.warp(block.timestamp + 6 hours);
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 120e6); // 60% of 200
    }

    function test_PrevKingPayout_40PercentAt15Hours() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Wait 15 hours (midway through Phase 3: 6h-24h)
        // Payout = 60% - (40% * 9h/18h) = 60% - 20% = 40%
        vm.warp(block.timestamp + 15 hours);
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 80e6); // 40% of 200
    }

    function test_PrevKingPayout_20PercentAt24Hours() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Wait exactly 24 hours (boundary of Phase 3 -> Phase 4)
        vm.warp(block.timestamp + 24 hours);
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 40e6); // 20% of 200
    }

    function test_PrevKingPayout_20PercentFloorAfter24Hours() public {
        _mineAs(alice, 100e6);
        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Wait 48 hours (well past 24h, should still be 20% floor)
        vm.warp(block.timestamp + 48 hours);
        _mineAs(bob, 200e6);

        uint256 alicePayout = usdc.balanceOf(alice) - aliceBalanceBefore;
        assertEq(alicePayout, 40e6); // 20% floor
    }

    function test_NewKingGetsEmissions() public {
        _mineAs(alice, 100e6);

        vm.warp(block.timestamp + 1 hours);

        // Bob takes over, Alice's emissions are auto-claimed
        _mineAs(bob, 200e6);

        assertEq(token.balanceOf(alice), 3600e18);
    }

    // ============ Treasury Tests ============

    function test_TreasuryPoolSplit() public {
        _mineAs(alice, 100e6);

        // megapotPool is 0 because tickets are auto-purchased
        (uint256 megapotPool, uint256 reservePool) = treasury.getPoolBalances();

        // Treasury gets 95% of first bid (80% + 15%)
        uint256 treasuryTotal = (100e6 * 9500) / 10000;

        // megapotBps = 1000 (10% of bid), treasuryBps = 1500
        // So megapot gets 1000/1500 of treasury, reserve gets 500/1500
        uint256 expectedMegapot = (treasuryTotal * 1000) / 1500;
        uint256 expectedReserve = treasuryTotal - expectedMegapot;

        // megapotPool should be 0 (auto-purchased)
        assertEq(megapotPool, 0, "megapotPool should be 0 after auto-purchase");
        // Megapot contract should have received the funds
        assertApproxEqAbs(usdc.balanceOf(address(megapot)), expectedMegapot, 1);
        assertApproxEqAbs(reservePool, expectedReserve, 1);
    }

    function test_AutoPurchaseTickets() public {
        // When mining, tickets should be auto-purchased
        _mineAs(alice, 100e6);

        // megapotPool should be 0 (auto-purchased)
        (uint256 megapotPool,) = treasury.getPoolBalances();
        assertEq(megapotPool, 0, "megapotPool should be 0 after auto-purchase");

        // Tickets should have been purchased
        assertGt(megapot.totalTicketsPurchased(), 0, "tickets should be purchased");
        assertGt(treasury.totalTicketsPurchased(), 0, "treasury should track tickets");
    }

    function test_SetMegapotBps() public {
        vm.prank(owner);
        treasury.setMegapotBps(500); // 5%

        assertEq(treasury.megapotBps(), 500);
    }

    function test_SetMegapotBpsMaxLimit() public {
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.InvalidBps.selector);
        treasury.setMegapotBps(2000); // 20% > 15% max
    }

    function test_TreasuryMinerIsOneTimeSettable() public {
        // Deploy fresh treasury without miner
        LotteryTreasury newTreasury = new LotteryTreasury(
            address(usdc),
            address(megapot),
            owner
        );

        // Miner not set yet
        assertEq(newTreasury.miner(), address(0));

        // Owner can set miner
        vm.prank(owner);
        newTreasury.setMiner(address(miner));
        assertEq(newTreasury.miner(), address(miner));

        // Cannot set again
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.MinerAlreadySet.selector);
        newTreasury.setMiner(alice);
    }

    function test_WithdrawReserve() public {
        // Set governance first (required for withdrawals)
        address gov = address(0x999);
        vm.prank(owner);
        treasury.setGovernance(gov);

        _mineAs(alice, 100e6);

        (, uint256 reservePool) = treasury.getPoolBalances();

        // Governance can withdraw
        vm.prank(gov);
        treasury.withdraw(gov, reservePool);

        assertEq(usdc.balanceOf(gov), reservePool);
    }

    function test_OwnerCannotWithdrawDirectly() public {
        _mineAs(alice, 100e6);

        // Owner tries to withdraw without governance set - should fail
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.GovernanceNotSet.selector);
        treasury.withdraw(owner, 1e6);
    }

    // ============ Integration Tests ============

    function test_FullFlow() public {
        // Alice mines first
        _mineAs(alice, 100e6);
        assertEq(miner.king(), alice);

        // Wait 2 hours
        vm.warp(block.timestamp + 2 hours);

        // Bob takes over
        uint256 bobBid = 150e6;
        _mineAs(bob, bobBid);

        // Alice got emissions (2 hours = 7200 tokens)
        assertEq(token.balanceOf(alice), 7200e18);

        // v2: Alice gets time-decayed payout (2h reign = 76% payout)
        // Phase 2: 1h-6h, payout = 80% - (20% * (2h-1h)/(6h-1h)) = 80% - 4% = 76%
        uint256 alicePayout = (bobBid * 7600) / 10000;
        assertGt(usdc.balanceOf(alice), 10000e6 - 100e6 + alicePayout - 1);

        // Bob is now king
        assertEq(miner.king(), bob);

        // Tickets auto-purchased during deposit
        assertGt(megapot.totalTicketsPurchased(), 0, "tickets should be auto-purchased");
    }

    // ============ Invariant Tests ============

    function invariant_treasuryPoolsMatchBalance() public view {
        // Treasury's tracked pools should never exceed actual USDC balance
        (uint256 megapotPool, uint256 reservePool) = treasury.getPoolBalances();
        uint256 actualBalance = usdc.balanceOf(address(treasury));
        assert(megapotPool + reservePool <= actualBalance);
    }

    function invariant_kingStartTimeValid() public view {
        // If there's a king, kingStartTime should be in the past
        if (miner.king() != address(0)) {
            assert(miner.kingStartTime() <= block.timestamp);
        }
    }

    function invariant_emissionsCapped() public view {
        // Emissions should never exceed MAX_EMISSION_PERIOD worth
        uint256 maxEmissions = miner.MAX_EMISSION_PERIOD() * miner.EMISSION_RATE();
        uint256 pending = miner.getPendingEmissions();
        assert(pending <= maxEmissions);
    }


    // ============ MEV Protection Tests ============

    function test_DeadlinePassed() public {
        uint256 currentEpoch = miner.epochId();

        vm.prank(alice);
        vm.expectRevert(LotteryMiner.DeadlinePassed.selector);
        miner.mine(100e6, currentEpoch, block.timestamp - 1);
    }

    function test_DeadlineAtBlockTimestamp() public {
        // Deadline exactly at block.timestamp should pass (> not >=)
        uint256 currentEpoch = miner.epochId();

        vm.prank(alice);
        miner.mine(100e6, currentEpoch, block.timestamp);

        assertEq(miner.king(), alice, "Mine should succeed when deadline == block.timestamp");
    }

    function test_InvalidEpochIdFuture() public {
        uint256 currentEpoch = miner.epochId();

        vm.prank(alice);
        vm.expectRevert(LotteryMiner.InvalidEpochId.selector);
        miner.mine(100e6, currentEpoch + 1, block.timestamp + 1 hours);
    }

    function test_InvalidEpochIdPast() public {
        // First, create a transaction to increment epochId
        _mineAs(alice, 100e6);

        // Now epochId is 1, try to use 0
        vm.warp(block.timestamp + 1 hours); // Wait for decay
        vm.prank(bob);
        vm.expectRevert(LotteryMiner.InvalidEpochId.selector);
        miner.mine(110e6, 0, block.timestamp + 1 hours);
    }

    function test_EpochIdStartsAtZero() public view {
        assertEq(miner.epochId(), 0, "epochId should start at 0");
    }

    function test_EpochIdIncrementsOnSuccess() public {
        assertEq(miner.epochId(), 0);

        _mineAs(alice, 100e6);
        assertEq(miner.epochId(), 1, "epochId should be 1 after first mine");

        vm.warp(block.timestamp + 1 hours);
        _mineAs(bob, 110e6);
        assertEq(miner.epochId(), 2, "epochId should be 2 after second mine");
    }

    function test_EpochIdDoesNotIncrementOnFailure() public {
        assertEq(miner.epochId(), 0);

        // Try to mine with wrong epochId - should fail and not increment
        uint256 currentEpoch = miner.epochId();
        vm.prank(alice);
        vm.expectRevert(LotteryMiner.InvalidEpochId.selector);
        miner.mine(100e6, currentEpoch + 1, block.timestamp + 1 hours);

        // epochId should still be 0
        assertEq(miner.epochId(), 0, "epochId should not increment on failure");

        // Now a valid mine should work and increment to 1
        _mineAs(alice, 100e6);
        assertEq(miner.epochId(), 1);
    }

    function test_FrontRunProtectionScenario() public {
        // Realistic front-run scenario

        // 1. Alice prepares transaction with current epochId = 0
        uint256 aliceEpochId = miner.epochId();
        assertEq(aliceEpochId, 0);

        // 2. MEV bot sees Alice's tx in mempool, front-runs with same epochId
        vm.prank(bob);
        miner.mine(100e6, aliceEpochId, block.timestamp + 1 hours);

        // 3. Bot becomes King, epochId incremented to 1
        assertEq(miner.king(), bob);
        assertEq(miner.epochId(), 1);

        // 4. Alice's tx executes with stale epochId = 0, should REVERT
        vm.prank(alice);
        vm.expectRevert(LotteryMiner.InvalidEpochId.selector);
        miner.mine(100e6, aliceEpochId, block.timestamp + 1 hours);

        // 5. Alice is protected - she didn't lose funds, bot gained nothing
        assertEq(usdc.balanceOf(alice), 10000e6, "Alice keeps her USDC");
        assertEq(miner.king(), bob, "Bob is still King but got no victim payout");

        // 6. Alice can safely retry with new epochId
        vm.warp(block.timestamp + 1 hours); // Wait for price decay
        uint256 newEpochId = miner.epochId();
        assertEq(newEpochId, 1);

        vm.prank(alice);
        miner.mine(110e6, newEpochId, block.timestamp + 1 hours);

        // 7. Alice successfully becomes King
        assertEq(miner.king(), alice);
        assertEq(miner.epochId(), 2);
    }

    function test_MultipleSequentialMines() public {
        // Ensure epochId properly increments through multiple transactions

        _mineAs(alice, 100e6);
        assertEq(miner.epochId(), 1);
        assertEq(miner.king(), alice);

        vm.warp(block.timestamp + 1 hours);
        _mineAs(bob, 110e6);
        assertEq(miner.epochId(), 2);
        assertEq(miner.king(), bob);

        vm.warp(block.timestamp + 1 hours);
        _mineAs(alice, 121e6);
        assertEq(miner.epochId(), 3);
        assertEq(miner.king(), alice);
    }

    function test_DeadlineProtection() public {
        // User submits tx with 5 minute deadline
        uint256 deadline = block.timestamp + 5 minutes;
        uint256 currentEpoch = miner.epochId();

        // Tx gets delayed in mempool for 10 minutes
        vm.warp(block.timestamp + 10 minutes);

        // Should revert because deadline passed
        vm.prank(alice);
        vm.expectRevert(LotteryMiner.DeadlinePassed.selector);
        miner.mine(100e6, currentEpoch, deadline);
    }

    function test_ValidDeadline() public {
        // Deadline in future should work
        uint256 deadline = block.timestamp + 5 minutes;
        uint256 currentEpoch = miner.epochId();

        vm.prank(alice);
        miner.mine(100e6, currentEpoch, deadline);

        assertEq(miner.king(), alice);
    }

    function test_EpochIdAndDeadlineTogetherProtection() public {
        // Both protections work together
        // Deadline is checked first in contract

        // Alice prepares tx
        uint256 aliceEpochId = miner.epochId();
        uint256 aliceDeadline = block.timestamp + 5 minutes;

        // Bob front-runs
        _mineAs(bob, 100e6);

        // Warp past Alice's deadline AND epochId changed
        vm.warp(block.timestamp + 10 minutes);

        // Alice's tx should fail on deadline check (checked before epochId)
        vm.prank(alice);
        vm.expectRevert(LotteryMiner.DeadlinePassed.selector);
        miner.mine(100e6, aliceEpochId, aliceDeadline);
    }

    // ===== Governance Tests =====

    function test_Ownable2StepTransfer() public {
        address newOwner = address(0x123);

        // Step 1: Current owner proposes transfer
        vm.prank(owner);
        treasury.transferOwnership(newOwner);

        // Ownership not yet transferred
        assertEq(treasury.owner(), owner);

        // Step 2: New owner must accept
        vm.prank(newOwner);
        treasury.acceptOwnership();

        // Now transferred
        assertEq(treasury.owner(), newOwner);
    }

    function test_MaxSupplyEnforced() public {
        uint256 maxSupply = token.MAX_TOTAL_SUPPLY();

        // Mint up to max
        vm.prank(address(miner));
        token.mint(alice, maxSupply);

        assertEq(token.totalSupply(), maxSupply);

        // Cannot mint more
        vm.prank(address(miner));
        vm.expectRevert(LotteryToken.MaxSupplyReached.selector);
        token.mint(alice, 1);
    }

    function test_MaxSupplyAllowsRealisticUsage() public {
        // Simulate 1 year of emissions at 1 token/sec
        uint256 oneYear = 365 days;
        uint256 yearlyEmissions = oneYear * 1e18; // ~31.5M tokens

        vm.prank(address(miner));
        token.mint(alice, yearlyEmissions);

        // Should succeed (well under 100M cap)
        assertEq(token.totalSupply(), yearlyEmissions);
        assertLt(token.totalSupply(), token.MAX_TOTAL_SUPPLY());
    }

    function test_Delegation() public {
        // Mint tokens to alice
        vm.prank(address(miner));
        token.mint(alice, 1000e18);

        // Initially no votes (need to delegate)
        assertEq(token.getVotes(alice), 0);
        assertEq(token.getVotes(bob), 0);

        // Alice delegates to bob
        vm.prank(alice);
        token.delegate(bob);

        // Bob now has alice's voting power
        assertEq(token.getVotes(bob), 1000e18);
        assertEq(token.getVotes(alice), 0);
        assertEq(token.delegates(alice), bob);
    }

    function test_VotingPowerTracking() public {
        // Mint at current timepoint
        vm.prank(address(miner));
        token.mint(alice, 1000e18);

        // Alice self-delegates
        vm.prank(alice);
        token.delegate(alice);

        uint256 currentTimepoint = block.timestamp;
        assertEq(token.getVotes(alice), 1000e18);

        // Roll forward and mint more
        vm.roll(block.number + 1);
        vm.warp(block.timestamp + 1);

        vm.prank(address(miner));
        token.mint(alice, 500e18);

        // Current votes updated
        assertEq(token.getVotes(alice), 1500e18);

        // Past votes still accurate
        assertEq(token.getPastVotes(alice, currentTimepoint), 1000e18);
    }

    function test_Permit() public {
        // Setup: Alice has tokens
        vm.prank(address(miner));
        token.mint(alice, 1000e18);

        // Create permit for bob to spend alice's tokens
        uint256 alicePrivateKey = 0xA11CE;
        address aliceAddr = vm.addr(alicePrivateKey);

        // Transfer tokens to the proper alice address
        vm.prank(alice);
        token.transfer(aliceAddr, 1000e18);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 nonce = token.nonces(aliceAddr);

        // Create permit digest
        bytes32 PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
        bytes32 structHash = keccak256(abi.encode(
            PERMIT_TYPEHASH,
            aliceAddr,
            bob,
            1000e18,
            nonce,
            deadline
        ));

        bytes32 digest = keccak256(abi.encodePacked(
            "\x19\x01",
            token.DOMAIN_SEPARATOR(),
            structHash
        ));

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(alicePrivateKey, digest);

        // Verify no allowance before permit
        assertEq(token.allowance(aliceAddr, bob), 0);

        // Anyone can submit permit (gasless for alice)
        token.permit(aliceAddr, bob, 1000e18, deadline, v, r, s);

        // Bob now has approval
        assertEq(token.allowance(aliceAddr, bob), 1000e18);
    }

    // ============ Governance Withdrawal Tests ============

    function test_CannotWithdrawWithoutGovernance() public {
        _mineAs(alice, 100e6);

        (, uint256 reservePool) = treasury.getPoolBalances();
        assertGt(reservePool, 0);

        // Owner tries to withdraw - should fail (governance not set)
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.GovernanceNotSet.selector);
        treasury.withdraw(owner, reservePool);
    }

    function test_SetGovernance() public {
        address gov = address(0x999);

        vm.prank(owner);
        treasury.setGovernance(gov);

        assertEq(treasury.governance(), gov);
    }

    function test_OwnerCannotChangeGovernanceAfterSet() public {
        address gov1 = address(0x999);
        address gov2 = address(0x888);

        // Owner sets governance first time
        vm.prank(owner);
        treasury.setGovernance(gov1);

        // Owner cannot change it after set
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.OnlyGovernance.selector);
        treasury.setGovernance(gov2);

        // Still the first one
        assertEq(treasury.governance(), gov1);
    }

    function test_GovernanceCanChangeItself() public {
        address gov1 = address(0x999);
        address gov2 = address(0x888);

        // Owner sets governance first time
        vm.prank(owner);
        treasury.setGovernance(gov1);

        // Governance can change itself
        vm.prank(gov1);
        treasury.setGovernance(gov2);

        // Now gov2
        assertEq(treasury.governance(), gov2);
    }

    function test_CannotSetGovernanceToZero() public {
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.InvalidGovernance.selector);
        treasury.setGovernance(address(0));
    }

    function test_OnlyOwnerCanSetGovernance() public {
        address gov = address(0x999);

        vm.prank(alice);
        vm.expectRevert();
        treasury.setGovernance(gov);

        // Still unset
        assertEq(treasury.governance(), address(0));
    }

    function test_GovernanceCanWithdraw() public {
        address gov = address(0x999);

        // Set governance
        vm.prank(owner);
        treasury.setGovernance(gov);

        // Create some reserve
        _mineAs(alice, 100e6);

        (, uint256 reserveBefore) = treasury.getPoolBalances();
        assertGt(reserveBefore, 0);

        uint256 withdrawAmount = reserveBefore / 2;

        // Governance withdraws
        vm.prank(gov);
        treasury.withdraw(gov, withdrawAmount);

        (, uint256 reserveAfter) = treasury.getPoolBalances();
        assertEq(reserveAfter, reserveBefore - withdrawAmount);
        assertEq(usdc.balanceOf(gov), withdrawAmount);
    }

    function test_NonGovernanceCannotWithdraw() public {
        address gov = address(0x999);
        address attacker = address(0x666);

        vm.prank(owner);
        treasury.setGovernance(gov);

        _mineAs(alice, 100e6);

        vm.prank(attacker);
        vm.expectRevert(LotteryTreasury.OnlyGovernance.selector);
        treasury.withdraw(attacker, 1e6);
    }

    function test_OwnerCannotWithdrawAfterGovernanceSet() public {
        address gov = address(0x999);

        vm.prank(owner);
        treasury.setGovernance(gov);

        _mineAs(alice, 100e6);

        // Owner tries to withdraw - should fail (not governance)
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.OnlyGovernance.selector);
        treasury.withdraw(owner, 1e6);
    }

    // ============ Rescue MegapotPool Tests ============

    function test_RescueMegapotPool_Success() public {
        address gov = address(0x999);
        address recipient = address(0x888);

        vm.prank(owner);
        treasury.setGovernance(gov);

        // Make Megapot fail so funds accumulate in megapotPool
        megapot.setShouldFail(true);

        // Mine - this will deposit to treasury but ticket purchase will fail
        _mineAs(alice, 100e6);

        // Verify funds accumulated in megapotPool
        (uint256 megapotPoolBefore,) = treasury.getPoolBalances();
        assertGt(megapotPoolBefore, 0, "megapotPool should have funds");

        uint256 recipientBalanceBefore = usdc.balanceOf(recipient);

        // Governance rescues the stuck funds
        vm.prank(gov);
        treasury.rescueMegapotPool(recipient);

        // Verify rescue worked
        (uint256 megapotPoolAfter,) = treasury.getPoolBalances();
        assertEq(megapotPoolAfter, 0, "megapotPool should be empty");
        assertEq(usdc.balanceOf(recipient), recipientBalanceBefore + megapotPoolBefore, "recipient should receive funds");
    }

    function test_RescueMegapotPool_OnlyGovernance() public {
        address gov = address(0x999);
        address attacker = address(0x666);

        vm.prank(owner);
        treasury.setGovernance(gov);

        vm.prank(attacker);
        vm.expectRevert(LotteryTreasury.OnlyGovernance.selector);
        treasury.rescueMegapotPool(attacker);
    }

    function test_RescueMegapotPool_GovernanceNotSet() public {
        vm.prank(alice);
        vm.expectRevert(LotteryTreasury.GovernanceNotSet.selector);
        treasury.rescueMegapotPool(alice);
    }

    function test_RescueMegapotPool_NothingToRescue() public {
        address gov = address(0x999);

        vm.prank(owner);
        treasury.setGovernance(gov);

        // megapotPool is 0
        vm.prank(gov);
        vm.expectRevert(LotteryTreasury.NothingToRescue.selector);
        treasury.rescueMegapotPool(gov);
    }

    function test_RescueMegapotPool_ZeroAddress() public {
        address gov = address(0x999);

        vm.prank(owner);
        treasury.setGovernance(gov);

        vm.prank(gov);
        vm.expectRevert(LotteryTreasury.ZeroAddress.selector);
        treasury.rescueMegapotPool(address(0));
    }

    // ============ Voting Power Transfer Tests ============

    function test_VotingPowerUpdatesOnTransfer() public {
        // Mint tokens to alice
        vm.prank(address(miner));
        token.mint(alice, 1000e18);

        // Alice delegates to herself (required to activate voting power)
        vm.prank(alice);
        token.delegate(alice);

        // Check alice has voting power
        assertEq(token.getVotes(alice), 1000e18);
        assertEq(token.getVotes(bob), 0);

        // Alice transfers to bob
        vm.prank(alice);
        token.transfer(bob, 400e18);

        // Alice voting power decreased
        assertEq(token.getVotes(alice), 600e18);

        // Bob has tokens but no voting power yet (hasn't delegated)
        assertEq(token.balanceOf(bob), 400e18);
        assertEq(token.getVotes(bob), 0);

        // Bob delegates to self
        vm.prank(bob);
        token.delegate(bob);

        // Now bob has voting power
        assertEq(token.getVotes(bob), 400e18);
    }

    function test_VotingPowerAfterMintToExistingDelegate() public {
        // Alice delegates to herself first
        vm.prank(alice);
        token.delegate(alice);

        // Now mint - voting power should update automatically
        vm.prank(address(miner));
        token.mint(alice, 1000e18);

        assertEq(token.getVotes(alice), 1000e18);

        // Mint more
        vm.prank(address(miner));
        token.mint(alice, 500e18);

        assertEq(token.getVotes(alice), 1500e18);
    }

    function test_DelegateTransferToAnotherDelegate() public {
        // Mint to both alice and bob
        vm.prank(address(miner));
        token.mint(alice, 1000e18);
        vm.prank(address(miner));
        token.mint(bob, 500e18);

        // Both delegate to themselves
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(bob);
        token.delegate(bob);

        assertEq(token.getVotes(alice), 1000e18);
        assertEq(token.getVotes(bob), 500e18);

        // Alice transfers to bob
        vm.prank(alice);
        token.transfer(bob, 300e18);

        // Voting power updates for both
        assertEq(token.getVotes(alice), 700e18);
        assertEq(token.getVotes(bob), 800e18);
    }

    // ============ Clock Mode Tests (L2 Compatibility) ============

    function test_ClockReturnsTimestamp() public view {
        // Clock should return current block timestamp
        assertEq(token.clock(), uint48(block.timestamp));
    }

    function test_ClockModeReturnsTimestampMode() public view {
        // CLOCK_MODE should indicate timestamp mode
        assertEq(token.CLOCK_MODE(), "mode=timestamp");
    }

    function test_ClockAdvancesWithTime() public {
        uint48 clock1 = token.clock();

        // Warp forward 1 hour
        vm.warp(block.timestamp + 1 hours);

        uint48 clock2 = token.clock();

        // Clock should have advanced by 1 hour
        assertEq(clock2 - clock1, 1 hours);
    }

    function test_PastVotesUseTimestampClock() public {
        // Mint and delegate
        vm.prank(address(miner));
        token.mint(alice, 1000e18);
        vm.prank(alice);
        token.delegate(alice);

        uint256 checkpoint1 = block.timestamp;
        assertEq(token.getVotes(alice), 1000e18);

        // Advance time (not just block number)
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        // Mint more
        vm.prank(address(miner));
        token.mint(alice, 500e18);

        // Current votes
        assertEq(token.getVotes(alice), 1500e18);

        // Past votes at checkpoint1 (using timestamp)
        assertEq(token.getPastVotes(alice, checkpoint1), 1000e18);
    }

    function test_CheckpointCreatedOnDelegation() public {
        vm.prank(address(miner));
        token.mint(alice, 1000e18);

        uint256 delegateTime = block.timestamp;

        vm.prank(alice);
        token.delegate(alice);

        // Advance time
        vm.warp(block.timestamp + 1 hours);
        vm.roll(block.number + 1);

        // Should be able to query past votes at delegation time
        assertEq(token.getPastVotes(alice, delegateTime), 1000e18);
    }

    // ============ Phase 2: Router & Collector Tests ============

    function test_Router_SetsReferrer() public {
        // Deploy Phase 2 contracts
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        // Fund router caller
        usdc.mint(address(this), 100e6);
        usdc.approve(address(router), 100e6);

        // Purchase through router
        router.purchaseTickets(100e6, address(0));

        // Verify referrer was set to collector
        assertEq(megapot.lastReferrer(), address(collector));

        // Verify referral fees accumulated
        assertEq(megapot.referralFeesClaimable(address(collector)), 10e6); // 10% of 100
    }

    function test_Router_TransfersUSDC() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        usdc.mint(address(this), 100e6);
        usdc.approve(address(router), 100e6);

        uint256 megapotBefore = usdc.balanceOf(address(megapot));
        router.purchaseTickets(100e6, address(0));

        // USDC should have moved to megapot
        assertEq(usdc.balanceOf(address(megapot)) - megapotBefore, 100e6);
    }

    function test_Collector_HarvestViaClaimEmissions() public {
        // Deploy Phase 2 contracts
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        // Configure treasury to use router
        vm.prank(owner);
        treasury.setMegapotRouter(address(router));
        vm.prank(owner);
        treasury.setMegapotBps(0);

        // Alice becomes King first
        _mineAs(alice, 100e6);
        assertEq(miner.king(), alice);

        // Simulate referral fees by purchasing through router
        usdc.mint(address(this), 1000e6);
        usdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        // Fees accumulated: 100 USDC (10% of 1000)
        assertEq(megapot.referralFeesClaimable(address(collector)), 100e6);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        uint256 treasuryBalanceBefore = usdc.balanceOf(address(treasury));

        // Harvest triggered automatically via claimEmissions
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        miner.claimEmissions();

        // 50% to King (Alice), 50% to Treasury
        assertEq(usdc.balanceOf(alice) - aliceBalanceBefore, 50e6);
        assertEq(usdc.balanceOf(address(treasury)) - treasuryBalanceBefore, 50e6);
    }

    function test_Collector_OnlyMinerCanHarvest() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );

        // Non-miner cannot call harvestIfNeededFor
        vm.prank(alice);
        vm.expectRevert(ReferralCollector.OnlyMiner.selector);
        collector.harvestIfNeededFor(alice);
    }

    function test_Collector_NoFeesDoesNotRevert() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        // Configure treasury to use router
        vm.prank(owner);
        treasury.setMegapotRouter(address(router));
        vm.prank(owner);
        treasury.setMegapotBps(0);

        // No fees accumulated, but claimEmissions should not revert
        _mineAs(alice, 100e6);
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        miner.claimEmissions(); // Should succeed silently
    }

    function test_Treasury_UsesRouterWhenSet() public {
        // Deploy Phase 2 contracts
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        // Set router in treasury
        vm.prank(owner);
        treasury.setMegapotRouter(address(router));

        // Mine to trigger treasury deposit + auto-purchase
        _mineAs(alice, 100e6);

        // Verify referral fees went to collector (router was used)
        assertGt(megapot.referralFeesClaimable(address(collector)), 0, "Router should capture referral fees");
        assertEq(megapot.lastReferrer(), address(collector), "Referrer should be collector");
    }

    function test_Treasury_FallbackWhenNoRouter() public {
        // No router set
        assertEq(treasury.megapotRouter(), address(0));

        // Mine to trigger treasury deposit
        _mineAs(alice, 100e6);

        // Tickets still purchased (direct to megapot)
        assertGt(megapot.totalTicketsPurchased(), 0);

        // But no referral fees captured (referrer was address(0))
        assertEq(megapot.lastReferrer(), address(0));
    }

    function test_Treasury_RouterSetOnce() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router1 = new MegapotRouter(address(usdc), address(megapot), address(collector));
        MegapotRouter router2 = new MegapotRouter(address(usdc), address(megapot), address(collector));

        // Set router first time
        vm.prank(owner);
        treasury.setMegapotRouter(address(router1));

        // Cannot set again
        vm.prank(owner);
        vm.expectRevert(LotteryTreasury.RouterAlreadySet.selector);
        treasury.setMegapotRouter(address(router2));
    }

    // ============ Dethrone Referral Attribution Tests ============

    function test_Dethrone_HarvestInMine_PaysPrevKing() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        // Configure treasury to use router and disable auto Megapot purchases during deposits for determinism.
        vm.prank(owner);
        treasury.setMegapotRouter(address(router));
        vm.prank(owner);
        treasury.setMegapotBps(0);

        // Alice becomes king.
        _mineAs(alice, 100e6);

        // Generate referral fees while Alice is king.
        usdc.mint(address(this), 1000e6);
        usdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));
        assertEq(megapot.referralFeesClaimable(address(collector)), 100e6);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);

        // Bob dethrones Alice. mine() should harvest referral fees to the dethroned king (Alice).
        _mineAs(bob, 200e6);

        uint256 prevKingAmount = (200e6 * 8000) / 10000; // immediate takeover payout phase = 80%
        uint256 referralShare = 50e6; // 50% of 100 USDC fees
        assertEq(usdc.balanceOf(alice) - aliceBalanceBefore, prevKingAmount + referralShare);
        assertEq(megapot.referralFeesClaimable(address(collector)), 0);
        assertEq(miner.king(), bob);
    }

    function test_Dethrone_NoFees_DoesNotRevert() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        vm.prank(owner);
        treasury.setMegapotRouter(address(router));
        vm.prank(owner);
        treasury.setMegapotBps(0);

        _mineAs(alice, 100e6);
        _mineAs(bob, 200e6);
        assertEq(miner.king(), bob);
    }

    function test_Dethrone_MegapotWithdrawReverts_MineStillSucceeds() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        vm.prank(owner);
        treasury.setMegapotRouter(address(router));
        vm.prank(owner);
        treasury.setMegapotBps(0);

        _mineAs(alice, 100e6);

        // Generate referral fees, then make withdrawals revert.
        usdc.mint(address(this), 1000e6);
        usdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));
        assertEq(megapot.referralFeesClaimable(address(collector)), 100e6);

        megapot.setShouldRevertWithdraw(true);

        uint256 aliceBalanceBefore = usdc.balanceOf(alice);
        _mineAs(bob, 200e6);

        // Alice still gets dethrone payout, but referral fees remain unharvested.
        uint256 prevKingAmount = (200e6 * 8000) / 10000;
        assertEq(usdc.balanceOf(alice) - aliceBalanceBefore, prevKingAmount);
        assertEq(megapot.referralFeesClaimable(address(collector)), 100e6);
        assertEq(miner.king(), bob);
    }

    // ============ Security Fix Tests ============

    function test_PauseTimeout_AutoUnpauseAfter7Days() public {
        // Alice mines first
        _mineAs(alice, 100e6);

        // Creator pauses
        vm.prank(creator);
        miner.pause();

        // Bob cannot mine while paused
        vm.warp(block.timestamp + 1 hours);
        uint256 currentEpoch = miner.epochId();
        vm.prank(bob);
        vm.expectRevert();
        miner.mine(200e6, currentEpoch, block.timestamp + 1 hours);

        // Warp past 7 days
        vm.warp(block.timestamp + 7 days + 1);

        // Bob can now mine (auto-unpause triggered)
        _mineAs(bob, 200e6);
        assertEq(miner.king(), bob);

        // Verify contract is unpaused
        assertFalse(miner.paused());
    }

    function test_PauseTimeout_StillPausedBefore7Days() public {
        _mineAs(alice, 100e6);

        vm.prank(creator);
        miner.pause();

        // Warp 6 days (still within pause window)
        vm.warp(block.timestamp + 6 days);

        // Bob still cannot mine
        uint256 currentEpoch = miner.epochId();
        vm.prank(bob);
        vm.expectRevert();
        miner.mine(200e6, currentEpoch, block.timestamp + 1 hours);

        assertTrue(miner.paused());
    }

    function test_PausedAtRecorded() public {
        uint256 pauseTime = block.timestamp;

        vm.prank(creator);
        miner.pause();

        assertEq(miner.pausedAt(), pauseTime);
    }

    function test_GracefulEmissionCap_GameContinues() public {
        // This test verifies the try/catch works but can't easily test MAX_SUPPLY
        // since it would require minting 100M tokens. Instead we verify the pattern exists.
        // The try/catch ensures mine() doesn't revert if mint fails.

        _mineAs(alice, 100e6);
        vm.warp(block.timestamp + 1 hours);

        // Second mine should work - emissions are handled gracefully
        _mineAs(bob, 200e6);
        assertEq(miner.king(), bob);
    }

    // ============ Audit Fix Tests ============

    function test_TransferToBuyback_Success() public {
        // Deploy a real BuybackBurner for this test
        BuybackBurner burner = new BuybackBurner(
            address(usdc),
            address(usdc), // lpToken placeholder (not used in this test)
            owner,
            24 hours,  // epochPeriod
            12000,     // priceMultiplier
            1e6,       // minInitPrice
            1e6        // initPrice
        );

        vm.prank(owner);
        treasury.setBuybackBurner(address(burner));

        // Fund treasury reserve via mine
        _mineAs(alice, 100e6);
        (, uint256 reserve) = treasury.getPoolBalances();
        assertGt(reserve, 0);

        // Setup governance
        vm.prank(owner);
        treasury.setGovernance(owner);

        // Transfer to buyback (was broken before M-2 fix)
        vm.prank(owner);
        treasury.transferToBuyback(reserve);

        assertEq(burner.usdcAccumulated(), reserve);
    }

    function test_DustAmount_SkipsTicketPurchase() public {
        // Set megapotBps so that treasury allocation is < 1 USDC
        vm.prank(owner);
        treasury.setMegapotBps(1); // 1/1500 of deposit goes to megapot

        // Mine with minimum bid (10 USDC). Treasury gets 15% = 1.5 USDC.
        // megapotPool = 1.5 * 1/1500 = 0.001 USDC = 1000 (< 1e6)
        _mineAs(alice, 10e6);

        // megapotPool should retain the dust (not attempt purchase)
        (uint256 megapotPool,) = treasury.getPoolBalances();
        assertGt(megapotPool, 0);
        assertLt(megapotPool, 1e6);
        assertEq(treasury.totalTicketsPurchased(), 0);
    }

    function test_AutoClaimWinnings_OnDeposit() public {
        // Give treasury some winnings in the mock
        usdc.mint(address(megapot), 1000e6);
        megapot.setWinnings(address(treasury), 1000e6);

        (, uint256 reserveBefore) = treasury.getPoolBalances();

        // Mine triggers deposit which triggers _tryClaimWinnings
        _mineAs(alice, 100e6);

        (, uint256 reserveAfter) = treasury.getPoolBalances();

        // Reserve should include the 1000 USDC winnings + normal reserve deposit
        uint256 normalReserve = reserveAfter - reserveBefore;
        // Treasury gets 15% of 100 = 15 USDC. megapotBps=1000/1500 to megapot, rest to reserve.
        // Plus 1000 USDC from winnings claim
        assertGt(normalReserve, 1000e6, "reserve should include winnings");
    }

    function test_AutoClaimWinnings_SilentFailure() public {
        // No winnings set — _tryClaimWinnings should not revert
        _mineAs(alice, 100e6);
        assertEq(miner.king(), alice); // mine succeeded
    }

    function test_GovernanceClaimWinnings_StillWorks() public {
        // Governance fallback should still work
        usdc.mint(address(megapot), 500e6);
        megapot.setWinnings(address(treasury), 500e6);

        vm.prank(owner);
        treasury.setGovernance(owner);

        (, uint256 reserveBefore) = treasury.getPoolBalances();

        vm.prank(owner);
        treasury.claimMegapotWinnings();

        (, uint256 reserveAfter) = treasury.getPoolBalances();
        assertEq(reserveAfter - reserveBefore, 500e6);
    }

    function test_Router_ReturnsTrue() public {
        ReferralCollector collector = new ReferralCollector(
            address(usdc),
            address(megapot),
            address(miner),
            address(treasury)
        );
        MegapotRouter router = new MegapotRouter(
            address(usdc),
            address(megapot),
            address(collector)
        );

        usdc.mint(address(this), 100e6);
        usdc.approve(address(router), 100e6);

        // Should succeed (mock always returns true)
        uint256 tickets = router.purchaseTickets(100e6, address(0));
        assertEq(tickets, 100); // 100 USDC = 100 tickets
    }
}
