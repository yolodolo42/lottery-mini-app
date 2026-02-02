// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/LotteryToken.sol";

contract DeployTokenScript is Script {
    function run() external returns (address token) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        console.log("=== Deploying LotteryToken ===");

        vm.startBroadcast(deployerPrivateKey);

        LotteryToken lotteryToken = new LotteryToken();
        console.log("LotteryToken:", address(lotteryToken));

        vm.stopBroadcast();

        return address(lotteryToken);
    }
}
