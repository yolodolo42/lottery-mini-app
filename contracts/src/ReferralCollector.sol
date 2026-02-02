// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./interfaces/IMegapot.sol";

/// @title ReferralCollector
/// @notice Collects Megapot referral fees and distributes them between King and Treasury
contract ReferralCollector is ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 public constant KING_BPS = 5000; // 50%
    uint256 public constant BPS_DENOMINATOR = 10000;

    IERC20 public immutable usdc;
    IMegapotFees public immutable megapot;
    ILotteryMiner public immutable miner;
    address public immutable treasury;

    event Harvested(uint256 total, uint256 toKing, uint256 toTreasury);

    error ZeroAddress();
    error NothingToHarvest();

    constructor(address _usdc, address _megapot, address _miner, address _treasury) {
        if (_usdc == address(0) || _megapot == address(0) || _miner == address(0) || _treasury == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(_usdc);
        megapot = IMegapotFees(_megapot);
        miner = ILotteryMiner(_miner);
        treasury = _treasury;
    }

    /// @notice Harvest referral fees from Megapot and distribute
    /// @dev Permissionless - anyone can call
    function harvest() external nonReentrant {
        // Cache king before withdrawal to prevent race condition with mine()
        address king = miner.king();

        uint256 claimable = megapot.referralFeesClaimable(address(this));
        if (claimable == 0) revert NothingToHarvest();

        uint256 balanceBefore = usdc.balanceOf(address(this));
        megapot.withdrawReferralFees();
        uint256 harvested = usdc.balanceOf(address(this)) - balanceBefore;

        uint256 kingAmount = 0;
        if (king != address(0)) {
            kingAmount = (harvested * KING_BPS) / BPS_DENOMINATOR;
            usdc.safeTransfer(king, kingAmount);
        }

        uint256 treasuryAmount = harvested - kingAmount;
        usdc.safeTransfer(treasury, treasuryAmount);

        emit Harvested(harvested, kingAmount, treasuryAmount);
    }

    /// @notice View pending referral fees
    function pendingFees() external view returns (uint256) {
        return megapot.referralFeesClaimable(address(this));
    }
}
