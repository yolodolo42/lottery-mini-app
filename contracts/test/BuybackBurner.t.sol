// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/BuybackBurner.sol";
import "../src/LotteryTreasury.sol";
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

// Mock LP Token
contract MockLPToken is ERC20 {
    constructor() ERC20("LOTTERY-USDC LP", "LP") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract BuybackBurnerTest is Test {
    MockUSDC public usdc;
    MockLPToken public lpToken;
    BuybackBurner public burner;

    address public owner = address(0x1);
    address public alice = address(0x2);
    address public bob = address(0x3);
    address constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 constant EPOCH_PERIOD = 24 hours;
    uint256 constant PRICE_MULTIPLIER = 12000; // 1.2x
    uint256 constant MIN_INIT_PRICE = 1e6; // 1 USDC per 1e18 LP
    uint256 constant INIT_PRICE = 10e6; // 10 USDC per 1e18 LP

    function setUp() public {
        usdc = new MockUSDC();
        lpToken = new MockLPToken();

        burner = new BuybackBurner(
            address(usdc),
            address(lpToken),
            owner,
            EPOCH_PERIOD,
            PRICE_MULTIPLIER,
            MIN_INIT_PRICE,
            INIT_PRICE
        );

        // Mint USDC and deposit to burner for auctions
        usdc.mint(owner, 1000e6);
        vm.startPrank(owner);
        usdc.approve(address(burner), 1000e6);
        burner.deposit(1000e6);
        vm.stopPrank();

        // Mint LP tokens to users
        lpToken.mint(alice, 1000e18);
        lpToken.mint(bob, 1000e18);
    }

    /*//////////////////////////////////////////////////////////////
                        CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Constructor_SetsParameters() public view {
        assertEq(address(burner.usdc()), address(usdc));
        assertEq(address(burner.lpToken()), address(lpToken));
        assertEq(burner.owner(), owner);
        assertEq(burner.epochPeriod(), EPOCH_PERIOD);
        assertEq(burner.priceMultiplier(), PRICE_MULTIPLIER);
        assertEq(burner.minInitPrice(), MIN_INIT_PRICE);
        assertEq(burner.initPrice(), INIT_PRICE);
        assertEq(burner.epochId(), 0);
    }

    function test_Constructor_RevertsZeroAddress() public {
        vm.expectRevert(BuybackBurner.ZeroAddress.selector);
        new BuybackBurner(address(0), address(lpToken), owner, EPOCH_PERIOD, PRICE_MULTIPLIER, MIN_INIT_PRICE, INIT_PRICE);

        vm.expectRevert(BuybackBurner.ZeroAddress.selector);
        new BuybackBurner(address(usdc), address(0), owner, EPOCH_PERIOD, PRICE_MULTIPLIER, MIN_INIT_PRICE, INIT_PRICE);

        // Note: Ownable2Step reverts with OwnableInvalidOwner for zero owner, not our custom error
    }

    function test_Constructor_RevertsInvalidParameters() public {
        vm.expectRevert(BuybackBurner.InvalidParameters.selector);
        new BuybackBurner(address(usdc), address(lpToken), owner, 0, PRICE_MULTIPLIER, MIN_INIT_PRICE, INIT_PRICE);

        vm.expectRevert(BuybackBurner.InvalidParameters.selector);
        new BuybackBurner(address(usdc), address(lpToken), owner, EPOCH_PERIOD, 10000, MIN_INIT_PRICE, INIT_PRICE);

        vm.expectRevert(BuybackBurner.InvalidParameters.selector);
        new BuybackBurner(address(usdc), address(lpToken), owner, EPOCH_PERIOD, PRICE_MULTIPLIER, 0, INIT_PRICE);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE DECAY TESTS
    //////////////////////////////////////////////////////////////*/

    function test_getCurrentPrice_StartsAtInitPrice() public view {
        assertEq(burner.getCurrentPrice(), INIT_PRICE);
    }

    function test_getCurrentPrice_DecaysLinearly() public {
        // At 25% of epoch, price should be 75% of initPrice
        vm.warp(block.timestamp + EPOCH_PERIOD / 4);
        uint256 expected = (INIT_PRICE * 3) / 4;
        assertEq(burner.getCurrentPrice(), expected);

        // At 50% of epoch, price should be 50% of initPrice
        vm.warp(block.timestamp + EPOCH_PERIOD / 4);
        expected = INIT_PRICE / 2;
        assertEq(burner.getCurrentPrice(), expected);

        // At 75% of epoch, price should be 25% of initPrice
        vm.warp(block.timestamp + EPOCH_PERIOD / 4);
        expected = INIT_PRICE / 4;
        assertEq(burner.getCurrentPrice(), expected);
    }

    function test_getCurrentPrice_ReturnsZeroAfterEpoch() public {
        vm.warp(block.timestamp + EPOCH_PERIOD);
        assertEq(burner.getCurrentPrice(), 0);

        vm.warp(block.timestamp + 1 days);
        assertEq(burner.getCurrentPrice(), 0);
    }

    /*//////////////////////////////////////////////////////////////
                        BUY FUNCTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Buy_Success() public {
        uint256 lpAmount = 1e18; // 1 LP token
        uint256 expectedUSDC = (lpAmount * INIT_PRICE) / 1e18;

        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount);
        burner.buy(lpAmount, 0, block.timestamp + 1 hours, expectedUSDC);
        vm.stopPrank();

        // Check LP burned to dead address
        assertEq(lpToken.balanceOf(DEAD), lpAmount);

        // Check alice received USDC
        assertEq(usdc.balanceOf(alice), expectedUSDC);

        // Check state updated
        assertEq(burner.totalLpBurned(), lpAmount);
        assertEq(burner.epochId(), 1);
    }

    function test_Buy_UpdatesEpochAndPrice() public {
        uint256 lpAmount = 1e18;
        uint256 price = burner.getCurrentPrice();

        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount);
        burner.buy(lpAmount, 0, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();

        // New init price should be currentPrice * priceMultiplier
        uint256 expectedNewPrice = (price * PRICE_MULTIPLIER) / 10000;
        assertEq(burner.initPrice(), expectedNewPrice);
        assertEq(burner.epochId(), 1);
    }

    function test_Buy_RevertsOnStaleEpochId() public {
        // First buy advances epoch
        uint256 lpAmount = 1e18;
        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount * 2);
        burner.buy(lpAmount, 0, block.timestamp + 1 hours, type(uint256).max);

        // Try to buy with old epochId
        vm.expectRevert(BuybackBurner.InvalidEpochId.selector);
        burner.buy(lpAmount, 0, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();
    }

    function test_Buy_RevertsAfterDeadline() public {
        uint256 lpAmount = 1e18;

        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount);

        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(BuybackBurner.DeadlinePassed.selector);
        burner.buy(lpAmount, 0, block.timestamp - 1, type(uint256).max);
        vm.stopPrank();
    }

    function test_Buy_RevertsOnAuctionEnded() public {
        vm.warp(block.timestamp + EPOCH_PERIOD + 1);

        uint256 lpAmount = 1e18;
        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount);

        vm.expectRevert(BuybackBurner.AuctionEnded.selector);
        burner.buy(lpAmount, 0, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();
    }

    function test_Buy_RevertsOnZeroAmount() public {
        vm.startPrank(alice);
        vm.expectRevert(BuybackBurner.ZeroAmount.selector);
        burner.buy(0, 0, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();
    }

    function test_Buy_BurnsLpToDeadAddress() public {
        uint256 lpAmount = 5e18;
        uint256 deadBalanceBefore = lpToken.balanceOf(DEAD);

        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount);
        burner.buy(lpAmount, 0, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();

        assertEq(lpToken.balanceOf(DEAD), deadBalanceBefore + lpAmount);
        assertEq(burner.totalLpBurned(), lpAmount);
    }

    function test_Buy_MultiplePurchases() public {
        // Alice buys
        uint256 lpAmount1 = 1e18;
        vm.startPrank(alice);
        lpToken.approve(address(burner), lpAmount1);
        burner.buy(lpAmount1, 0, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();

        // Bob buys in next epoch
        uint256 lpAmount2 = 2e18;
        vm.startPrank(bob);
        lpToken.approve(address(burner), lpAmount2);
        burner.buy(lpAmount2, 1, block.timestamp + 1 hours, type(uint256).max);
        vm.stopPrank();

        assertEq(burner.totalLpBurned(), lpAmount1 + lpAmount2);
        assertEq(burner.epochId(), 2);
    }

    /*//////////////////////////////////////////////////////////////
                        DEPOSIT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deposit_Success() public {
        uint256 amount = 100e6;
        usdc.mint(alice, amount);

        vm.startPrank(alice);
        usdc.approve(address(burner), amount);
        burner.deposit(amount);
        vm.stopPrank();

        assertEq(burner.usdcAccumulated(), 1000e6 + amount);
    }

    function test_Deposit_RevertsOnZeroAmount() public {
        vm.startPrank(alice);
        vm.expectRevert(BuybackBurner.ZeroAmount.selector);
        burner.deposit(0);
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        PARAMETER UPDATE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_SetParameters_OnlyOwner() public {
        vm.prank(owner);
        burner.setParameters(12 hours, 15000, 2e6);

        assertEq(burner.epochPeriod(), 12 hours);
        assertEq(burner.priceMultiplier(), 15000);
        assertEq(burner.minInitPrice(), 2e6);
    }

    function test_SetParameters_RevertsNonOwner() public {
        vm.prank(alice);
        vm.expectRevert();
        burner.setParameters(12 hours, 15000, 2e6);
    }

    function test_SetParameters_RevertsInvalid() public {
        vm.startPrank(owner);

        vm.expectRevert(BuybackBurner.InvalidParameters.selector);
        burner.setParameters(0, 15000, 2e6);

        vm.expectRevert(BuybackBurner.InvalidParameters.selector);
        burner.setParameters(12 hours, 10000, 2e6);

        vm.expectRevert(BuybackBurner.InvalidParameters.selector);
        burner.setParameters(12 hours, 15000, 0);

        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                        VIEW TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetAuctionState_ReturnsCorrectValues() public view {
        (
            uint256 epochId_,
            uint256 currentPrice_,
            uint256 initPrice_,
            uint256 startTime_,
            uint256 usdcAccumulated_,
            uint256 totalLpBurned_
        ) = burner.getAuctionState();

        assertEq(epochId_, 0);
        assertEq(currentPrice_, INIT_PRICE);
        assertEq(initPrice_, INIT_PRICE);
        assertEq(startTime_, block.timestamp);
        assertEq(usdcAccumulated_, 1000e6);
        assertEq(totalLpBurned_, 0);
    }
}
