// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/LotteryMiner.sol";

contract DeployMinerScript is Script {
    function run() external returns (address miner) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address usdc = vm.envAddress("USDC");
        address token = vm.envAddress("TOKEN");
        address treasury = vm.envAddress("TREASURY");
        address creator = vm.envOr("CREATOR", deployer);

        console.log("=== Deploying LotteryMiner ===");
        console.log("USDC:", usdc);
        console.log("Token:", token);
        console.log("Treasury:", treasury);
        console.log("Creator (5% fee):", creator);

        vm.startBroadcast(deployerPrivateKey);

        LotteryMiner lotteryMiner = new LotteryMiner(usdc, token, creator, treasury);
        console.log("LotteryMiner:", address(lotteryMiner));

        vm.stopBroadcast();

        return address(lotteryMiner);
    }
}
