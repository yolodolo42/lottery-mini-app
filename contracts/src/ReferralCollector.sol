// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IMegapot.sol";

/// @title ReferralCollector
/// @notice Collects Megapot referral fees and distributes them between King and Treasury
/// @dev Only callable by the LotteryMiner during dethrone and claimEmissions
contract ReferralCollector is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant KING_BPS = 5000; // 50%
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable usdc;
    IMegapot public immutable megapot;
    ILotteryMiner public immutable miner;
    address public immutable treasury;

    event Harvested(uint256 total, uint256 toKing, uint256 toTreasury);

    error ZeroAddress();
    error OnlyMiner();

    modifier onlyMiner() {
        if (msg.sender != address(miner)) revert OnlyMiner();
        _;
    }

    constructor(address _usdc, address _megapot, address _miner, address _treasury) {
        if (_usdc == address(0) || _megapot == address(0) || _miner == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(_usdc);
        megapot = IMegapot(_megapot);
        miner = ILotteryMiner(_miner);
        treasury = _treasury;
    }

    /// @notice Miner-only: harvest referral fees and send king share to the specified recipient
    /// @dev Called automatically during mine() and claimEmissions(). Returns silently if nothing to harvest.
    function harvestIfNeededFor(address kingRecipient) external nonReentrant onlyMiner {
        uint256 balanceBefore = usdc.balanceOf(address(this));

        // Try to withdraw referral fees from Megapot. Return silently if it fails.
        try megapot.withdrawReferralFees() {} catch {
            return;
        }

        uint256 harvested = usdc.balanceOf(address(this)) - balanceBefore;
        if (harvested == 0) return;

        uint256 kingAmount = 0;
        if (kingRecipient != address(0)) {
            kingAmount = (harvested * KING_BPS) / BPS_DENOMINATOR;
            usdc.safeTransfer(kingRecipient, kingAmount);
        }

        uint256 treasuryAmount = harvested - kingAmount;
        usdc.safeTransfer(treasury, treasuryAmount);

        emit Harvested(harvested, kingAmount, treasuryAmount);
    }
}
