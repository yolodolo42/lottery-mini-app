// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LotteryToken.sol";
import "../src/LotteryTreasury.sol";

/// @title Configure
/// @notice Link contracts after individual deployments
/// @dev Usage:
///   TOKEN=0x... TREASURY=0x... MINER=0x... ROUTER=0x... \
///   forge script deployments/Configure.s.sol --rpc-url $RPC --broadcast
contract ConfigureScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address token = vm.envAddress("TOKEN");
        address treasury = vm.envAddress("TREASURY");
        address miner = vm.envAddress("MINER");
        address router = vm.envAddress("ROUTER");

        console.log("=== Configuring Contracts ===");
        console.log("Token:", token);
        console.log("Treasury:", treasury);
        console.log("Miner:", miner);
        console.log("Router:", router);

        vm.startBroadcast(deployerPrivateKey);

        // Set miner in token
        LotteryToken(token).setMiner(miner);
        console.log("Token.setMiner done");

        // Set miner in treasury
        LotteryTreasury(treasury).setMiner(miner);
        console.log("Treasury.setMiner done");

        // Set router in treasury
        LotteryTreasury(treasury).setMegapotRouter(router);
        console.log("Treasury.setMegapotRouter done");

        vm.stopBroadcast();

        console.log("\n=== Configuration Complete ===");
    }
}
