// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

interface ILotteryToken {
    function mint(address to, uint256 amount) external;
}

interface ILotteryTreasury {
    function deposit(uint256 amount) external;
    function megapotRouter() external view returns (address);
}

// Minimal interfaces for the referral-fee dethrone fix.
interface IMegapotRouterLike {
    function referralCollector() external view returns (address);
}

interface IReferralCollectorLike {
    function harvestIfNeededFor(address kingRecipient) external;
}

contract LotteryMiner is ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // Emission constants
    uint256 public constant EMISSION_RATE = 1e18; // 1 token per second
    uint256 public constant MAX_EMISSION_PERIOD = 7 days;

    // Fee distribution (basis points)
    uint256 public constant BPS_DENOMINATOR = 10000;
    uint256 public constant CREATOR_BPS = 500; // 5%
    uint256 public constant TREASURY_BPS = 1500; // 15%

    // Bid constraints
    uint256 public constant MIN_FIRST_BID = 10e6; // 10 USDC
    uint256 public constant MIN_BID_ABS = 10e6; // 10 USDC absolute floor

    // Price decay phases (bid price decreases over time)
    uint256 public constant DECAY_PHASE_A_END = 1 hours; // 2x -> 1.1x
    uint256 public constant DECAY_PHASE_B_END = 24 hours; // 1.1x -> MIN_BID_ABS

    // Previous king payout phases (payout decreases with longer reign)
    uint256 public constant PAYOUT_PHASE_1_END = 1 hours; // 80%
    uint256 public constant PAYOUT_PHASE_2_END = 6 hours; // 80% -> 60%
    uint256 public constant PAYOUT_PHASE_3_END = 24 hours; // 60% -> 20%
    uint256 public constant PREV_KING_BPS_MAX = 8000; // 80%
    uint256 public constant PREV_KING_BPS_MID = 6000; // 60%
    uint256 public constant PREV_KING_BPS_MIN = 2000; // 20%

    // Emergency pause timeout
    uint256 public constant MAX_PAUSE_DURATION = 7 days;

    // Immutables
    IERC20 public immutable usdc;
    ILotteryToken public immutable lotteryToken;
    address public immutable creator;
    ILotteryTreasury public immutable treasury;

    // State
    address public king;
    uint256 public kingStartTime; // Resets on claim (for emissions calculation)
    uint256 public reignStartTime; // Never resets (for UI display)
    uint256 public lastBidAmount;
    uint256 public lastBidTime;
    uint256 public epochId;
    uint256 public pausedAt;

    // Events
    event NewKing(address indexed king, uint256 bidAmount, uint256 previousKingPayout);
    event EmissionsClaimed(address indexed king, uint256 amount);
    event EmissionsCapReached(address indexed king, uint256 amount);

    // Errors
    error BidTooLow(uint256 required, uint256 provided);
    error NoEmissionsToClaim();
    error NotKing();
    error ZeroAddress();
    error OnlyCreator();
    error DeadlinePassed();
    error InvalidEpochId();

    modifier onlyCreator() {
        if (msg.sender != creator) revert OnlyCreator();
        _;
    }

    constructor(address _usdc, address _lotteryToken, address _creator, address _treasury) {
        if (_usdc == address(0) || _lotteryToken == address(0) || _creator == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(_usdc);
        lotteryToken = ILotteryToken(_lotteryToken);
        creator = _creator;
        treasury = ILotteryTreasury(_treasury);
    }

    /// @notice Creator: pause mining in case of emergency
    /// @dev Auto-unpauses after MAX_PAUSE_DURATION (7 days)
    function pause() external onlyCreator {
        pausedAt = block.timestamp;
        _pause();
    }

    /// @notice Creator: unpause mining
    function unpause() external onlyCreator {
        _unpause();
    }

    /// @notice Bid to become King
    /// @param bidAmount Amount of USDC to bid
    /// @param _epochId Must match current epochId (front-run protection)
    /// @param deadline Transaction must execute before this timestamp
    function mine(uint256 bidAmount, uint256 _epochId, uint256 deadline) external nonReentrant {
        // Auto-unpause after MAX_PAUSE_DURATION to prevent permanent freeze
        if (paused()) {
            if (block.timestamp >= pausedAt + MAX_PAUSE_DURATION) {
                _unpause();
            } else {
                revert EnforcedPause();
            }
        }

        if (block.timestamp > deadline) revert DeadlinePassed();
        if (_epochId != epochId) revert InvalidEpochId();

        uint256 minBid = getMinimumBid();
        if (bidAmount < minBid) revert BidTooLow(minBid, bidAmount);

        // Cache previous king state before modifications
        address prevKing = king;
        uint256 prevKingEmissions = _calculateEmissions();

        // Calculate fee splits
        uint256 prevKingBps = _getPrevKingBps();
        uint256 prevKingAmount = (bidAmount * prevKingBps) / BPS_DENOMINATOR;
        uint256 creatorAmount = (bidAmount * CREATOR_BPS) / BPS_DENOMINATOR;
        uint256 treasuryAmount = bidAmount - prevKingAmount - creatorAmount;

        // First bid: previous king share goes to treasury
        if (prevKing == address(0)) {
            treasuryAmount += prevKingAmount;
            prevKingAmount = 0;
        }

        // Update state before external calls (CEI pattern)
        king = msg.sender;
        kingStartTime = block.timestamp;
        reignStartTime = block.timestamp; // Track actual reign start (never resets on claim)
        lastBidAmount = bidAmount;
        lastBidTime = block.timestamp;
        unchecked { epochId++; }

        // Transfer USDC from bidder
        usdc.safeTransferFrom(msg.sender, address(this), bidAmount);

        // Best-effort: harvest Megapot referral fees for the dethroned king
        if (prevKing != address(0)) {
            _tryHarvestFor(prevKing);
        }

        // Settle previous king
        if (prevKing != address(0)) {
            if (prevKingEmissions > 0) {
                try lotteryToken.mint(prevKing, prevKingEmissions) {
                    emit EmissionsClaimed(prevKing, prevKingEmissions);
                } catch {
                    emit EmissionsCapReached(prevKing, prevKingEmissions);
                }
            }
            usdc.safeTransfer(prevKing, prevKingAmount);
        }

        usdc.safeTransfer(creator, creatorAmount);

        usdc.forceApprove(address(treasury), treasuryAmount);
        treasury.deposit(treasuryAmount);

        emit NewKing(msg.sender, bidAmount, prevKingAmount);
    }

    function claimEmissions() external nonReentrant {
        if (msg.sender != king) revert NotKing();

        uint256 emissions = _calculateEmissions();
        if (emissions == 0) revert NoEmissionsToClaim();

        kingStartTime = block.timestamp;
        lotteryToken.mint(king, emissions);

        emit EmissionsClaimed(king, emissions);

        // Best-effort: harvest Megapot referral fees for current king
        _tryHarvestFor(king);
    }

    /// @dev Best-effort harvest of Megapot referral fees. Fails silently to avoid DoS.
    function _tryHarvestFor(address recipient) internal {
        address router = treasury.megapotRouter();
        if (router == address(0)) return;
        try IMegapotRouterLike(router).referralCollector() returns (address collector) {
            if (collector != address(0)) {
                try IReferralCollectorLike(collector).harvestIfNeededFor(recipient) {} catch {}
            }
        } catch {}
    }

    function _calculateEmissions() internal view returns (uint256) {
        if (king == address(0)) return 0;

        uint256 elapsed = block.timestamp - kingStartTime;
        uint256 cappedElapsed = elapsed > MAX_EMISSION_PERIOD ? MAX_EMISSION_PERIOD : elapsed;
        return cappedElapsed * EMISSION_RATE;
    }

    /// @dev Calculate prev king payout BPS based on reign duration (time-decaying)
    function _getPrevKingBps() internal view returns (uint256) {
        uint256 elapsed = block.timestamp - lastBidTime;

        // Phase 1: 0-1h -> 80% (immediate takeover rewards attacker)
        if (elapsed <= PAYOUT_PHASE_1_END) {
            return PREV_KING_BPS_MAX;
        }

        // Phase 2: 1h-6h -> linear decay from 80% to 60%
        if (elapsed <= PAYOUT_PHASE_2_END) {
            uint256 phaseElapsed = elapsed - PAYOUT_PHASE_1_END;
            uint256 phaseDuration = PAYOUT_PHASE_2_END - PAYOUT_PHASE_1_END;
            uint256 bpsDecay = PREV_KING_BPS_MAX - PREV_KING_BPS_MID;
            return PREV_KING_BPS_MAX - (bpsDecay * phaseElapsed) / phaseDuration;
        }

        // Phase 3: 6h-24h -> linear decay from 60% to 20%
        if (elapsed <= PAYOUT_PHASE_3_END) {
            uint256 phaseElapsed = elapsed - PAYOUT_PHASE_2_END;
            uint256 phaseDuration = PAYOUT_PHASE_3_END - PAYOUT_PHASE_2_END;
            uint256 bpsDecay = PREV_KING_BPS_MID - PREV_KING_BPS_MIN;
            return PREV_KING_BPS_MID - (bpsDecay * phaseElapsed) / phaseDuration;
        }

        // Phase 4: >24h -> 20% floor
        return PREV_KING_BPS_MIN;
    }

    function getCurrentPrice() public view returns (uint256) {
        if (lastBidAmount == 0) return 0;

        uint256 elapsed = block.timestamp - lastBidTime;

        // Phase A: 0-1h -> linear decay from 2x to 1.1x
        if (elapsed < DECAY_PHASE_A_END) {
            uint256 startPrice = lastBidAmount * 2;
            uint256 endPrice = (lastBidAmount * 11000) / BPS_DENOMINATOR;
            uint256 priceDecay = startPrice - endPrice;
            return startPrice - (priceDecay * elapsed) / DECAY_PHASE_A_END;
        }

        // Phase B: 1h-24h -> linear decay from 1.1x to MIN_BID_ABS
        if (elapsed < DECAY_PHASE_B_END) {
            uint256 startPrice = (lastBidAmount * 11000) / BPS_DENOMINATOR;
            if (startPrice <= MIN_BID_ABS) return MIN_BID_ABS;

            uint256 phaseElapsed = elapsed - DECAY_PHASE_A_END;
            uint256 phaseDuration = DECAY_PHASE_B_END - DECAY_PHASE_A_END;
            uint256 priceDecay = startPrice - MIN_BID_ABS;
            return startPrice - (priceDecay * phaseElapsed) / phaseDuration;
        }

        // Phase C: >24h -> floor price
        return MIN_BID_ABS;
    }

    function getMinimumBid() public view returns (uint256) {
        if (lastBidAmount == 0) return MIN_FIRST_BID;

        uint256 currentPrice = getCurrentPrice();
        return currentPrice > MIN_BID_ABS ? currentPrice : MIN_BID_ABS;
    }

    function getPendingEmissions() external view returns (uint256) {
        return _calculateEmissions();
    }

    function getKingInfo() external view returns (
        address currentKing,
        uint256 reignStart,
        uint256 pendingEmissions,
        uint256 currentBid
    ) {
        return (king, reignStartTime, _calculateEmissions(), lastBidAmount);
    }
}
