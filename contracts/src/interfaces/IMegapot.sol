// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IMegapot {
    function purchaseTickets(address referrer, uint256 value, address recipient) external returns (bool);
    function currentDrawingId() external view returns (uint256);
}

interface IMegapotRouter {
    function purchaseTickets(uint256 value, address recipient) external returns (uint256);
}

interface IMegapotFees {
    function withdrawReferralFees() external;
    function referralFeesClaimable(address) external view returns (uint256);
}

interface ILotteryMiner {
    function king() external view returns (address);
}
