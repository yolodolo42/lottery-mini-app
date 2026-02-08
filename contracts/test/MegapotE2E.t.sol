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

/// @title MegapotE2EBase
/// @notice Abstract fork test base. Concrete subcontracts supply chain-specific
///         addresses and funding logic (mint vs deal).
abstract contract MegapotE2EBase is Test {
    // Subclass overrides
    function _megapotAddr() internal pure virtual returns (address);
    function _usdcAddr() internal pure virtual returns (address);
    function _forkLabel() internal pure virtual returns (string memory);
    function _fundAccount(address account, uint256 amount) internal virtual;

    // Real contracts
    IMegapot megapot;
    IERC20 usdc;

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
        vm.createSelectFork(_forkLabel());

        megapot = IMegapot(_megapotAddr());
        usdc = IERC20(_usdcAddr());

        // Read real referral fee rate
        referralFeeBps = megapot.referralFeeBps();

        // Deploy our contracts pointing at real Megapot + USDC
        token = new LotteryToken();
        treasury = new LotteryTreasury(_usdcAddr(), _megapotAddr(), owner);
        miner = new LotteryMiner(_usdcAddr(), address(token), creator, address(treasury));
        collector = new ReferralCollector(_usdcAddr(), _megapotAddr(), address(miner), address(treasury));
        router = new MegapotRouter(_usdcAddr(), _megapotAddr(), address(collector));

        // Wire one-time setters
        token.setMiner(address(miner));
        vm.prank(owner);
        treasury.setMiner(address(miner));
        vm.prank(owner);
        treasury.setMegapotRouter(address(router));

        // Fund test accounts
        _fundAccount(alice, 100_000e6);
        _fundAccount(bob, 100_000e6);
        _fundAccount(address(this), 100_000e6);

        // Approve miner
        vm.prank(alice);
        usdc.approve(address(miner), type(uint256).max);
        vm.prank(bob);
        usdc.approve(address(miner), type(uint256).max);
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
        usdc.approve(address(router), 100e6);
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
        usdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        uint256 expectedTotal = (1000e6 * referralFeeBps) / 10000;
        assertEq(megapot.referralFeesClaimable(address(collector)), expectedTotal, "fees accumulated");

        uint256 aliceBefore = usdc.balanceOf(alice);
        uint256 treasuryBefore = usdc.balanceOf(address(treasury));

        // Harvest via miner prank (collector is onlyMiner)
        vm.prank(address(miner));
        collector.harvestIfNeededFor(alice);

        uint256 aliceGot = usdc.balanceOf(alice) - aliceBefore;
        uint256 treasuryGot = usdc.balanceOf(address(treasury)) - treasuryBefore;
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
        usdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        uint256 expectedReferralTotal = (1000e6 * referralFeeBps) / 10000;
        uint256 expectedReferralShare = expectedReferralTotal / 2;
        uint256 aliceBefore = usdc.balanceOf(alice);

        // Bob dethrones Alice
        _mineAs(bob, 200e6);
        assertEq(miner.king(), bob);

        uint256 aliceGot = usdc.balanceOf(alice) - aliceBefore;
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
        usdc.approve(address(router), 1000e6);
        router.purchaseTickets(1000e6, address(0));

        uint256 expectedReferralTotal = (1000e6 * referralFeeBps) / 10000;
        uint256 expectedReferralShare = expectedReferralTotal / 2;
        uint256 aliceUsdcBefore = usdc.balanceOf(alice);

        // Warp and claim emissions
        vm.warp(block.timestamp + 1 hours);
        vm.prank(alice);
        miner.claimEmissions();

        // Alice gets LOTTERY emissions
        assertEq(token.balanceOf(alice), 3600e18, "1 hour of emissions");

        // Alice also gets 50% of referral fees
        uint256 aliceUsdcGot = usdc.balanceOf(alice) - aliceUsdcBefore;
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
        usdc.approve(address(router), 100e6);
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

// ============ Base Sepolia ============

contract MegapotSepoliaE2E is MegapotE2EBase {
    function _megapotAddr() internal pure override returns (address) {
        return 0x6f03c7BCaDAdBf5E6F5900DA3d56AdD8FbDac5De;
    }

    function _usdcAddr() internal pure override returns (address) {
        return 0xA4253E7C13525287C56550b8708100f93E60509f;
    }

    function _forkLabel() internal pure override returns (string memory) {
        return "base_sepolia";
    }

    function _fundAccount(address account, uint256 amount) internal override {
        IMintable(_usdcAddr()).mint(account, amount);
    }
}

// ============ Base Mainnet ============

contract MegapotMainnetE2E is MegapotE2EBase {
    function _megapotAddr() internal pure override returns (address) {
        return 0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95;
    }

    function _usdcAddr() internal pure override returns (address) {
        return 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    }

    function _forkLabel() internal pure override returns (string memory) {
        return "base";
    }

    function _fundAccount(address account, uint256 amount) internal override {
        deal(_usdcAddr(), account, amount);
    }
}
