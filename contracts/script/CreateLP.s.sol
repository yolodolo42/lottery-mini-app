// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

interface IUniswapV2Pair {
    function mint(address to) external returns (uint256 liquidity);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface ILotteryToken {
    function premineForLP(address lpPair) external;
    function balanceOf(address) external view returns (uint256);
    function PREMINE_AMOUNT() external view returns (uint256);
}

/// @title CreateLP
/// @notice Creates LOTTERY-USDC LP pair and initializes liquidity
/// @dev Usage: forge script script/CreateLP.s.sol:CreateLPScript --rpc-url $RPC --broadcast
contract CreateLPScript is Script {
    // Uniswap V2 Factory on Base Sepolia (from Base docs)
    address constant UNISWAP_V2_FACTORY = 0x7Ae58f10f7849cA6F5fB71b7f45CB416c9204b1e;

    // USDC amount for LP (1000 USDC with 6 decimals)
    uint256 constant USDC_AMOUNT = 1000e6;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        // Get addresses from environment or use defaults
        address lottery = vm.envAddress("LOTTERY_TOKEN");
        address usdc = vm.envAddress("USDC");

        console.log("========================================");
        console.log("         CREATE LP PAIR                 ");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("LOTTERY:", lottery);
        console.log("USDC:", usdc);
        console.log("========================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Create pair
        console.log("--- Step 1: Creating Uniswap V2 Pair ---");
        IUniswapV2Factory factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);

        address pair = factory.getPair(lottery, usdc);
        if (pair == address(0)) {
            pair = factory.createPair(lottery, usdc);
            console.log("Created new pair:", pair);
        } else {
            console.log("Pair already exists:", pair);
        }
        console.log("");

        // Step 2: Premine LOTTERY to pair
        console.log("--- Step 2: Premine LOTTERY to Pair ---");
        ILotteryToken token = ILotteryToken(lottery);
        uint256 premineAmount = token.PREMINE_AMOUNT();
        console.log("Premine amount:", premineAmount / 1e18, "LOTTERY");

        token.premineForLP(pair);
        console.log("Premined to pair");
        console.log("Pair LOTTERY balance:", token.balanceOf(pair) / 1e18);
        console.log("");

        // Step 3: Transfer USDC to pair
        console.log("--- Step 3: Transfer USDC to Pair ---");
        console.log("USDC amount:", USDC_AMOUNT / 1e6, "USDC");

        IERC20(usdc).transfer(pair, USDC_AMOUNT);
        console.log("Transferred USDC to pair");
        console.log("");

        // Step 4: Mint LP tokens
        console.log("--- Step 4: Mint LP Tokens ---");
        uint256 liquidity = IUniswapV2Pair(pair).mint(deployer);
        console.log("LP tokens minted:", liquidity);
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("========================================");
        console.log("         LP CREATION COMPLETE           ");
        console.log("========================================");
        console.log("LP Pair:", pair);
        console.log("LOTTERY in pool:", token.balanceOf(pair) / 1e18);
        console.log("USDC in pool:", IERC20(usdc).balanceOf(pair) / 1e6);
        console.log("LP tokens received:", liquidity);
        console.log("Price: $", (USDC_AMOUNT * 1e18) / premineAmount / 1e12, "per LOTTERY");
        console.log("========================================");
    }
}
