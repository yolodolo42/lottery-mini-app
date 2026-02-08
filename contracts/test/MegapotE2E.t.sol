// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/LotteryToken.sol";
import "../src/LotteryMiner.sol";
import "../src/LotteryTreasury.sol";
import "../src/MegapotRouter.sol";
import "../src/ReferralCollector.sol";
import "../src/interfaces/IMegapot.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @dev Testnet MPUSDC has a public mint function
interface IMintable {
    function mint(address to, uint256 amount) external;
}

/// @title MegapotE2E
/// @notice Fork tests against real Megapot on Base Sepolia.
/// Validates: ticket purchases, referral fee accumulation + withdrawal,
/// auto-harvest on dethrone/claim, treasury auto-buy, usersInfo decoding.
contract MegapotE2E is Test {
    // Real Base Sepolia addresses
    address constant MEGAPOT = 0x6f03c7BCaDAdBf5E6F5900DA3d56AdD8FbDac5De;
    address constant MPUSDC = 0xA4253E7C13525287C56550b8708100f93E60509f;

    // Real contracts
    IMegapot megapot = IMegapot(MEGAPOT);
    IERC20 mpusdc = IERC20(MPUSDC);

    // Our contracts
    LotteryToken token;
    LotteryMiner miner;
    LotteryTreasury treasury;
    ReferralCollector collector;
    MegapotRouter router;

    // Test accounts
    address creator = address(0xC1);
    address owner = address(0xC2);
    address alice = address(0xA1);
    address bob = address(0xB1);

    // Cached referral fee rate
    uint256 referralFeeBps;

    function setUp() public {
        vm.createSelectFork("base_sepolia");

        // Read real referral fee rate
        referralFeeBps = megapot.referralFeeBps();

        // Deploy our contracts pointing at real Megapot + MPUSDC
        token = new LotteryToken();
        treasury = new LotteryTreasury(MPUSDC, MEGAPOT, owner);
        miner = new LotteryMiner(MPUSDC, address(token), creator, address(treasury));
        collector = new ReferralCollector(MPUSDC, MEGAPOT, address(miner), address(treasury));
        router = new MegapotRouter(MPUSDC, MEGAPOT, address(collector));

        // Wire one-time setters
        token.setMiner(address(miner));
        vm.prank(owner);
        treasury.setMiner(address(miner));
        vm.prank(owner);
        treasury.setMegapotRouter(address(router));

        // Mint MPUSDC to test accounts
        IMintable(MPUSDC).mint(alice, 100_000e6);
        IMintable(MPUSDC).mint(bob, 100_000e6);
        IMintable(MPUSDC).mint(address(this), 100_000e6);

        // Approve miner
        vm.prank(alice);
        mpusdc.approve(address(miner), type(uint256).max);
        vm.prank(bob);
        mpusdc.approve(address(miner), type(uint256).max);
    }

    function _mineAs(address caller, uint256 bidAmount) internal {
        uint256 currentEpoch = miner.epochId();
        vm.prank(caller);
        miner.mine(bidAmount, currentEpoch, block.timestamp + 1 hours);
    }

    // ============ Test 1: referralFeeBps returns nonzero ============

    function test_RealMegapot_ReferralFeeBps() public {
        assertGt(referralFeeBps, 0, "referralFeeBps should be nonzero");
        emit log_named_uint("referralFeeBps", referralFeeBps);
    }

    // ============ Test 2: Purchase tickets via our Router ============

    function test_RealMegapot_PurchaseTicketsViaRouter() public {
        mpusdc.approve(address(router), 100e6);
        uint256 tickets = router.purchaseTickets(100e6, address(0));
        assertGt(tickets, 0, "should return ticket count");

        // Referral fees should have accumulated for collector
        uint256 fees = megapot.referralFeesClaimable(address(collector));
        uint256 expectedFees = (100e6 * referralFeeBps) / 10000;
        assertEq(fees, expectedFees, "referral fees should accumulate");

        emit log_named_uint("tickets purchased", tickets);
        emit log_named_uint("referral fees accumulated", fees);
    }

    // ============ Test 3: Withdraw referral fees via collector ============

    function test_RealMegapot_WithdrawReferralFees() public {
        // Purchase tickets to generate referral fees for collector
        mpusdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        uint256 expectedTotal = (1000e6 * referralFeeBps) / 10000;
        assertEq(megapot.referralFeesClaimable(address(collector)), expectedTotal, "fees accumulated");

        uint256 aliceBefore = mpusdc.balanceOf(alice);
        uint256 treasuryBefore = mpusdc.balanceOf(address(treasury));

        // Harvest via miner prank (collector is onlyMiner)
        vm.prank(address(miner));
        collector.harvestIfNeededFor(alice);

        uint256 aliceGot = mpusdc.balanceOf(alice) - aliceBefore;
        uint256 treasuryGot = mpusdc.balanceOf(address(treasury)) - treasuryBefore;
        uint256 expectedHalf = expectedTotal / 2;

        assertEq(aliceGot, expectedHalf, "alice gets 50% of referral fees");
        assertEq(treasuryGot, expectedTotal - expectedHalf, "treasury gets 50% of referral fees");
        assertEq(megapot.referralFeesClaimable(address(collector)), 0, "fees fully withdrawn");

        emit log_named_uint("alice share", aliceGot);
        emit log_named_uint("treasury share", treasuryGot);
    }

    // ============ Test 4: Auto-harvest on dethrone ============

    function test_RealMegapot_AutoHarvestOnDethrone() public {
        // Disable megapot ticket purchases to isolate referral math
        vm.prank(owner);
        treasury.setMegapotBps(0);

        // Alice becomes king
        _mineAs(alice, 100e6);
        assertEq(miner.king(), alice);

        // Generate referral fees while Alice is king
        mpusdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        uint256 expectedReferralTotal = (1000e6 * referralFeeBps) / 10000;
        uint256 expectedReferralShare = expectedReferralTotal / 2;
        uint256 aliceBefore = mpusdc.balanceOf(alice);

        // Bob dethrones Alice
        _mineAs(bob, 200e6);
        assertEq(miner.king(), bob);

        uint256 aliceGot = mpusdc.balanceOf(alice) - aliceBefore;
        uint256 prevKingPayout = (200e6 * 8000) / 10000; // 80% of 200

        // Alice gets: prevKingPayout + 50% of referral fees
        assertEq(aliceGot, prevKingPayout + expectedReferralShare, "alice gets payout + referral share");
        assertEq(megapot.referralFeesClaimable(address(collector)), 0, "fees fully harvested");

        emit log_named_uint("alice total", aliceGot);
        emit log_named_uint("prevKingPayout", prevKingPayout);
        emit log_named_uint("referralShare", expectedReferralShare);
    }

    // ============ Test 5: Auto-harvest on claimEmissions ============

    function test_RealMegapot_AutoHarvestOnClaimEmissions() public {
        // Disable megapot ticket purchases to isolate referral math
        vm.prank(owner);
        treasury.setMegapotBps(0);

        // Alice becomes king
        _mineAs(alice, 100e6);

        // Generate referral fees
        mpusdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        uint256 expectedReferralTotal = (1000e6 * referralFeeBps) / 10000;
        uint256 expectedReferralShare = expectedReferralTotal / 2;
        uint256 aliceUsdcBefore = mpusdc.balanceOf(alice);

        // Warp and claim emissions
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        miner.claimEmissions();

        // Alice gets LOTTERY emissions
        assertEq(token.balanceOf(alice), 3600e18, "1 hour of emissions");

        // Alice also gets 50% of referral fees
        uint256 aliceUsdcGot = mpusdc.balanceOf(alice) - aliceUsdcBefore;
        assertEq(aliceUsdcGot, expectedReferralShare, "alice gets referral share on claim");
        assertEq(megapot.referralFeesClaimable(address(collector)), 0, "fees fully harvested");

        emit log_named_uint("alice USDC from referrals", aliceUsdcGot);
        emit log_named_uint("alice LOTTERY emissions", token.balanceOf(alice) / 1e18);
    }

    // ============ Test 6: Treasury auto-buys Megapot tickets ============

    function test_RealMegapot_TreasuryAutobuysTickets() public {
        _mineAs(alice, 100e6);

        assertGt(treasury.totalTicketsPurchased(), 0, "tickets should be auto-purchased");

        (uint256 megapotPool,) = treasury.getPoolBalances();
        assertEq(megapotPool, 0, "megapotPool should be drained");

        emit log_named_uint("totalTicketsPurchased", treasury.totalTicketsPurchased());
    }

    // ============ Test 7: usersInfo decodes correctly ============

    function test_RealMegapot_UsersInfoDecodes() public {
        mpusdc.approve(address(router), 100e6);
        router.purchaseTickets(100e6, address(0));

        // Decode usersInfo for collector (referrer)
        (uint256 ticketsBps, uint256 winnings, bool active) = megapot.usersInfo(address(collector));
        emit log_named_uint("collector ticketsBps", ticketsBps);
        emit log_named_uint("collector winnings", winnings);
        emit log_named_uint("collector active", active ? 1 : 0);

        // referralFeesClaimable should also decode
        uint256 fees = megapot.referralFeesClaimable(address(collector));
        assertGt(fees, 0, "referralFeesClaimable should work");
        emit log_named_uint("collector referralFeesClaimable", fees);
    }

    // ============ Test 8: claimMegapotWinnings reverts with no winnings ============

    function test_RealMegapot_ClaimWinningsRevertsWhenNone() public {
        address gov = address(0x999);
        vm.prank(owner);
        treasury.setGovernance(gov);

        vm.prank(gov);
        vm.expectRevert(LotteryTreasury.NothingToClaim.selector);
        treasury.claimMegapotWinnings();
    }
}
