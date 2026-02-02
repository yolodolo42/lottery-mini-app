// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IBuybackBurner {
    function deposit(uint256 amount) external;
    function getCurrentPrice() external view returns (uint256);
    function epochId() external view returns (uint256);
    function usdcAccumulated() external view returns (uint256);
}
