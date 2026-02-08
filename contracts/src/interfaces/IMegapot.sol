// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @dev Matches real deployed Megapot ABI (verified against Base Sepolia 0x6f03c7BC...)
/// NOTE: Docs say singular "withdrawReferralFee" but deployed bytecode uses plural "withdrawReferralFees"
/// NOTE: purchaseTickets returns void on-chain (not bool). Callers must use low-level call.
interface IMegapot {
    function purchaseTickets(address referrer, uint256 value, address recipient) external;
    function withdrawReferralFees() external; // PLURAL - verified against deployed bytecode
    function withdrawWinnings() external;
    function usersInfo(address) external view returns (uint256 ticketsPurchasedTotalBps, uint256 winningsClaimable, bool active);
    function referralFeeBps() external view returns (uint256);
    function referralFeesClaimable(address user) external view returns (uint256);
}

interface IMegapotRouter {
    function purchaseTickets(uint256 value, address recipient) external returns (uint256);
}

interface ILotteryMiner {
    function king() external view returns (address);
}
