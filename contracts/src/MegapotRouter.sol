// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IMegapot.sol";

/// @title MegapotRouter
/// @notice Routes Megapot ticket purchases with referral fees directed to ReferralCollector
contract MegapotRouter {
    using SafeERC20 for IERC20;

    uint256 private constant TICKET_PRICE = 1e6; // 1 USDC per ticket
    bytes4 private constant PURCHASE_TICKETS_SELECTOR =
        bytes4(keccak256("purchaseTickets(address,uint256,address)"));

    IERC20 public immutable usdc;
    IMegapot public immutable megapot;
    address public immutable referralCollector;

    error ZeroAddress();
    error MegapotPurchaseFailed();

    constructor(address _usdc, address _megapot, address _referralCollector) {
        if (_usdc == address(0) || _megapot == address(0) || _referralCollector == address(0)) {
            revert ZeroAddress();
        }
        usdc = IERC20(_usdc);
        megapot = IMegapot(_megapot);
        referralCollector = _referralCollector;
    }

    /// @notice Purchase Megapot tickets with referral set to ReferralCollector
    /// @param value USDC amount to spend on tickets
    /// @param recipient Address to receive the tickets (address(0) for msg.sender)
    /// @return ticketCount Number of tickets purchased
    function purchaseTickets(uint256 value, address recipient) external returns (uint256 ticketCount) {
        usdc.safeTransferFrom(msg.sender, address(this), value);
        usdc.forceApprove(address(megapot), value);

        // Tolerate Megapot implementations that either return (bool) or return nothing.
        (bool ok, bytes memory ret) = address(megapot).call(
            abi.encodeWithSelector(PURCHASE_TICKETS_SELECTOR, referralCollector, value, recipient)
        );
        if (!ok) revert MegapotPurchaseFailed();
        if (ret.length == 32 && !abi.decode(ret, (bool))) revert MegapotPurchaseFailed();
        if (ret.length != 0 && ret.length != 32) revert MegapotPurchaseFailed();

        return value / TICKET_PRICE;
    }
}
