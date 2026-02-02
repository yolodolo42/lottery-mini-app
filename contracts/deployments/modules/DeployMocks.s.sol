// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Mock USDC for testnet
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {}

    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @notice Mock Megapot for testnet
contract MockMegapot {
    IERC20 public usdc;
    uint256 public totalTicketsPurchased;
    uint256 public currentDrawingId;
    mapping(address => uint256) public referralFees;

    constructor(address _usdc) {
        usdc = IERC20(_usdc);
        currentDrawingId = 1;
    }

    function purchaseTickets(address referrer, uint256 value, address) external returns (bool) {
        usdc.transferFrom(msg.sender, address(this), value);
        totalTicketsPurchased += value / 1e6;
        // Simulate 5% referral fee
        if (referrer != address(0)) {
            referralFees[referrer] += (value * 500) / 10000;
        }
        return true;
    }

    function referralFeesClaimable(address referrer) external view returns (uint256) {
        return referralFees[referrer];
    }

    function withdrawReferralFees() external {
        uint256 amount = referralFees[msg.sender];
        referralFees[msg.sender] = 0;
        usdc.transfer(msg.sender, amount);
    }

    function advanceDrawing() external {
        currentDrawingId++;
    }
}

contract DeployMocksScript is Script {
    function run() external returns (address usdc, address megapot) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console.log("=== Deploying Mocks ===");
        console.log("Deployer:", deployer);

        vm.startBroadcast(deployerPrivateKey);

        MockUSDC mockUsdc = new MockUSDC();
        console.log("MockUSDC:", address(mockUsdc));

        MockMegapot mockMegapot = new MockMegapot(address(mockUsdc));
        console.log("MockMegapot:", address(mockMegapot));

        // Mint test USDC to deployer
        mockUsdc.mint(deployer, 100_000e6); // 100k USDC
        console.log("Minted 100,000 USDC to deployer");

        vm.stopBroadcast();

        return (address(mockUsdc), address(mockMegapot));
    }
}
