// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IMegapot.sol";
import "./interfaces/IBuybackBurner.sol";

contract LotteryTreasury is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Constants
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant MAX_MEGAPOT_BPS = 1500; // Max 15% of total bid
    uint256 public constant TREASURY_BPS = 1500; // Treasury always gets 15% of bid

    // Immutables
    IERC20 public immutable usdc;
    IMegapot public immutable megapot;

    // State
    address public miner;
    uint256 public megapotBps = 1000; // Default 10% of treasury allocation
    uint256 public megapotPool;
    uint256 public reservePool;
    uint256 public totalTicketsPurchased;
    mapping(uint256 => uint256) public ticketsByRound;
    address public governance;
    address public megapotRouter;
    address public buybackBurner;

    // Events
    event Deposit(uint256 amount, uint256 toMegapot, uint256 toReserve);
    event TicketsPurchased(uint256 indexed drawingId, uint256 amount, uint256 tickets);
    event TicketPurchaseFailed(uint256 amount);
    event MegapotBpsUpdated(uint256 oldBps, uint256 newBps);
    event Withdrawn(address indexed to, uint256 amount);
    event GovernanceSet(address indexed governance);
    event MegapotPoolRescued(address indexed to, uint256 amount);
    event TransferredToBuyback(uint256 amount);

    // Errors
    error OnlyMiner();
    error InvalidBps();
    error InsufficientReserve();
    error ZeroAddress();
    error InvalidGovernance();
    error OnlyGovernance();
    error GovernanceNotSet();
    error OnlyOwnerOrGovernance();
    error MinerAlreadySet();
    error MinerNotSet();
    error RouterAlreadySet();
    error BuybackBurnerAlreadySet();
    error NothingToRescue();

    modifier onlyMiner() {
        if (miner == address(0)) revert MinerNotSet();
        if (msg.sender != miner) revert OnlyMiner();
        _;
    }

    constructor(
        address _usdc,
        address _megapot,
        address _owner
    ) Ownable(_owner) {
        if (_usdc == address(0) || _megapot == address(0) || _owner == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(_usdc);
        megapot = IMegapot(_megapot);
    }

    /// @notice Owner: set miner address (one-time only)
    function setMiner(address _miner) external onlyOwner {
        if (miner != address(0)) revert MinerAlreadySet();
        if (_miner == address(0)) revert ZeroAddress();
        miner = _miner;
    }

    /// @notice Owner: set Megapot router address (one-time only)
    function setMegapotRouter(address _router) external onlyOwner {
        if (megapotRouter != address(0)) revert RouterAlreadySet();
        if (_router == address(0)) revert ZeroAddress();
        megapotRouter = _router;
    }

    /// @notice Owner: set BuybackBurner address (one-time only)
    function setBuybackBurner(address _burner) external onlyOwner {
        if (buybackBurner != address(0)) revert BuybackBurnerAlreadySet();
        if (_burner == address(0)) revert ZeroAddress();
        buybackBurner = _burner;
    }

    /// @notice Called by miner to deposit treasury fees
    /// @param amount Total USDC amount from miner
    function deposit(uint256 amount) external onlyMiner nonReentrant {
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Split deposit between megapot tickets and reserve
        uint256 toMegapot = (amount * megapotBps) / TREASURY_BPS;
        uint256 toReserve = amount - toMegapot;

        megapotPool += toMegapot;
        reservePool += toReserve;

        emit Deposit(amount, toMegapot, toReserve);

        _tryPurchaseTickets();
    }

    function _tryPurchaseTickets() internal {
        uint256 amount = megapotPool;
        if (amount == 0) return;

        uint256 drawingId;
        try megapot.currentDrawingId() returns (uint256 id) {
            drawingId = id;
        } catch {
            emit TicketPurchaseFailed(amount);
            return;
        }

        try this._executePurchase(amount, drawingId) {} catch {
            emit TicketPurchaseFailed(amount);
        }
    }

    function _executePurchase(uint256 amount, uint256 drawingId) external {
        require(msg.sender == address(this), "internal only");

        megapotPool = 0;

        // Use router for referral fee capture when configured, otherwise direct purchase
        if (megapotRouter != address(0)) {
            usdc.forceApprove(megapotRouter, amount);
            IMegapotRouter(megapotRouter).purchaseTickets(amount, address(0));
        } else {
            usdc.forceApprove(address(megapot), amount);
            megapot.purchaseTickets(address(0), amount, address(0));
        }

        uint256 ticketCount = amount / 1e6;
        ticketsByRound[drawingId] += ticketCount;
        totalTicketsPurchased += ticketCount;

        emit TicketsPurchased(drawingId, amount, ticketCount);
    }

    /// @notice Owner: update megapot percentage
    /// @param newBps New basis points (0-1500, representing 0-15% of total bid)
    function setMegapotBps(uint256 newBps) external onlyOwner {
        if (newBps > MAX_MEGAPOT_BPS) revert InvalidBps();

        uint256 oldBps = megapotBps;
        megapotBps = newBps;

        emit MegapotBpsUpdated(oldBps, newBps);
    }

    /// @notice Set governance address
    /// @dev First time: only owner can set. After that: only governance can change itself.
    /// @param _governance Address of TimelockController or Governor for withdrawals
    function setGovernance(address _governance) external {
        if (governance == address(0)) {
            // First time: only owner can set
            if (msg.sender != owner()) revert OwnableUnauthorizedAccount(msg.sender);
        } else {
            // After that: only governance can change itself
            if (msg.sender != governance) revert OnlyGovernance();
        }
        if (_governance == address(0)) revert InvalidGovernance();
        governance = _governance;
        emit GovernanceSet(_governance);
    }

    /// @notice Governance: withdraw from reserve pool (only callable by governance)
    function withdraw(address to, uint256 amount) external {
        if (governance == address(0)) revert GovernanceNotSet();
        if (msg.sender != governance) revert OnlyGovernance();
        if (amount > reservePool) revert InsufficientReserve();

        reservePool -= amount;
        usdc.safeTransfer(to, amount);

        emit Withdrawn(to, amount);
    }

    /// @notice Governance: rescue stuck megapotPool if Megapot is permanently unavailable
    /// @param to Address to receive rescued funds
    function rescueMegapotPool(address to) external {
        if (governance == address(0)) revert GovernanceNotSet();
        if (msg.sender != governance) revert OnlyGovernance();
        if (to == address(0)) revert ZeroAddress();

        uint256 amount = megapotPool;
        if (amount == 0) revert NothingToRescue();

        megapotPool = 0;
        usdc.safeTransfer(to, amount);

        emit MegapotPoolRescued(to, amount);
    }

    /// @notice Governance: transfer USDC from reserve to BuybackBurner for LP auction
    /// @param amount Amount of USDC to transfer
    function transferToBuyback(uint256 amount) external {
        if (governance == address(0)) revert GovernanceNotSet();
        if (msg.sender != governance) revert OnlyGovernance();
        if (buybackBurner == address(0)) revert ZeroAddress();
        if (amount > reservePool) revert InsufficientReserve();

        reservePool -= amount;
        usdc.safeTransfer(buybackBurner, amount);
        IBuybackBurner(buybackBurner).deposit(amount);

        emit TransferredToBuyback(amount);
    }

    /// @notice View: get pool balances
    function getPoolBalances() external view returns (uint256 megapot_, uint256 reserve_) {
        return (megapotPool, reservePool);
    }
}
