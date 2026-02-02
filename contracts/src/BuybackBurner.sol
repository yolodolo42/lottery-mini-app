// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BuybackBurner
/// @notice Dutch auction that sells USDC for LOTTERY-USDC LP tokens, then burns them
/// @dev LP tokens are burned to 0xdead, permanently reducing LP supply
contract BuybackBurner is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant BPS_DENOMINATOR = 10000;
    address public constant DEAD_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    // Immutables
    IERC20 public immutable usdc;
    IERC20 public immutable lpToken;

    // Configurable parameters (owner can update)
    uint256 public epochPeriod;      // Duration of auction (default: 24 hours)
    uint256 public priceMultiplier;  // Multiplier after purchase (default: 12000 = 1.2x)
    uint256 public minInitPrice;     // Minimum starting price (floor)

    // Auction state
    uint256 public epochId;          // Current epoch (increments on purchase)
    uint256 public initPrice;        // Starting price for current epoch
    uint256 public startTime;        // When current epoch started
    uint256 public usdcAccumulated;  // USDC available for auction
    uint256 public totalLpBurned;    // Lifetime LP tokens burned

    // Events
    event AuctionPurchase(
        address indexed buyer,
        uint256 lpAmount,
        uint256 usdcAmount,
        uint256 epochId
    );
    event LpBurned(uint256 amount);
    event UsdcDeposited(address indexed from, uint256 amount);
    event ParametersUpdated(uint256 epochPeriod, uint256 priceMultiplier, uint256 minInitPrice);

    // Errors
    error ZeroAddress();
    error DeadlinePassed();
    error InvalidEpochId();
    error AuctionEnded();
    error InsufficientUsdcReserve();
    error InvalidParameters();
    error ZeroAmount();

    constructor(
        address _usdc,
        address _lpToken,
        address _owner,
        uint256 _epochPeriod,
        uint256 _priceMultiplier,
        uint256 _minInitPrice,
        uint256 _initPrice
    ) Ownable(_owner) {
        if (_usdc == address(0) || _lpToken == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        if (_epochPeriod == 0 || _priceMultiplier <= BPS_DENOMINATOR || _minInitPrice == 0) {
            revert InvalidParameters();
        }

        usdc = IERC20(_usdc);
        lpToken = IERC20(_lpToken);

        epochPeriod = _epochPeriod;
        priceMultiplier = _priceMultiplier;
        minInitPrice = _minInitPrice;
        initPrice = _initPrice;
        startTime = block.timestamp;
    }

    /// @notice Calculate current auction price (linearly decaying)
    /// @return Current USDC amount per 1e18 LP token
    function getCurrentPrice() public view returns (uint256) {
        uint256 elapsed = block.timestamp - startTime;
        if (elapsed >= epochPeriod) return 0;

        // Linear decay: price = initPrice * (epochPeriod - elapsed) / epochPeriod
        return (initPrice * (epochPeriod - elapsed)) / epochPeriod;
    }

    /// @notice Buy USDC with LP tokens
    /// @param lpAmount Amount of LP tokens to provide
    /// @param _epochId Must match current epochId (frontrun protection)
    /// @param deadline Transaction must execute before this timestamp
    /// @param maxUsdcExpected Maximum USDC expected (slippage protection)
    function buy(
        uint256 lpAmount,
        uint256 _epochId,
        uint256 deadline,
        uint256 maxUsdcExpected
    ) external nonReentrant {
        if (block.timestamp > deadline) revert DeadlinePassed();
        if (_epochId != epochId) revert InvalidEpochId();
        if (lpAmount == 0) revert ZeroAmount();

        uint256 price = getCurrentPrice();
        if (price == 0) revert AuctionEnded();

        // Calculate USDC to give for LP tokens received
        // price is USDC per 1e18 LP, so: usdcAmount = (lpAmount * price) / 1e18
        uint256 usdcAmount = (lpAmount * price) / 1e18;

        if (usdcAmount > usdcAccumulated) revert InsufficientUsdcReserve();
        if (usdcAmount > maxUsdcExpected) revert("Slippage exceeded");

        // Update state before external calls (CEI pattern)
        usdcAccumulated -= usdcAmount;

        // Calculate new init price for next epoch
        uint256 newInitPrice = (price * priceMultiplier) / BPS_DENOMINATOR;
        if (newInitPrice < minInitPrice) newInitPrice = minInitPrice;

        initPrice = newInitPrice;
        startTime = block.timestamp;
        unchecked { epochId++; }

        // Transfer LP tokens from buyer
        lpToken.safeTransferFrom(msg.sender, address(this), lpAmount);

        // Send USDC to buyer
        usdc.safeTransfer(msg.sender, usdcAmount);

        // Burn the LP tokens
        _burnLp(lpAmount);

        emit AuctionPurchase(msg.sender, lpAmount, usdcAmount, _epochId);
    }

    /// @notice Deposit USDC to be auctioned (callable by treasury)
    /// @param amount Amount of USDC to deposit
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert ZeroAmount();

        usdc.safeTransferFrom(msg.sender, address(this), amount);
        usdcAccumulated += amount;

        emit UsdcDeposited(msg.sender, amount);
    }

    /// @notice Owner: Update auction parameters
    /// @param _epochPeriod New epoch duration
    /// @param _priceMultiplier New price multiplier (BPS)
    /// @param _minInitPrice New minimum init price
    function setParameters(
        uint256 _epochPeriod,
        uint256 _priceMultiplier,
        uint256 _minInitPrice
    ) external onlyOwner {
        if (_epochPeriod == 0 || _priceMultiplier <= BPS_DENOMINATOR || _minInitPrice == 0) {
            revert InvalidParameters();
        }

        epochPeriod = _epochPeriod;
        priceMultiplier = _priceMultiplier;
        minInitPrice = _minInitPrice;

        emit ParametersUpdated(_epochPeriod, _priceMultiplier, _minInitPrice);
    }

    /// @notice View: Get auction state
    function getAuctionState() external view returns (
        uint256 _epochId,
        uint256 _currentPrice,
        uint256 _initPrice,
        uint256 _startTime,
        uint256 _usdcAccumulated,
        uint256 _totalLpBurned
    ) {
        return (
            epochId,
            getCurrentPrice(),
            initPrice,
            startTime,
            usdcAccumulated,
            totalLpBurned
        );
    }

    /// @dev Internal function to burn LP tokens to 0xdead
    function _burnLp(uint256 amount) internal {
        lpToken.safeTransfer(DEAD_ADDRESS, amount);
        totalLpBurned += amount;
        emit LpBurned(amount);
    }
}
