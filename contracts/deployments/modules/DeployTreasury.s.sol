// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/LotteryTreasury.sol";

contract DeployTreasuryScript is Script {
    function run() external returns (address treasury) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address usdc = vm.envAddress("USDC");
        address megapot = vm.envAddress("MEGAPOT");
        address owner = vm.envOr("OWNER", deployer);

        console.log("=== Deploying LotteryTreasury ===");
        console.log("USDC:", usdc);
        console.log("Megapot:", megapot);
        console.log("Owner:", owner);

        vm.startBroadcast(deployerPrivateKey);

        LotteryTreasury lotteryTreasury = new LotteryTreasury(usdc, megapot, owner);
        console.log("LotteryTreasury:", address(lotteryTreasury));

        vm.stopBroadcast();

        return address(lotteryTreasury);
    }
}
