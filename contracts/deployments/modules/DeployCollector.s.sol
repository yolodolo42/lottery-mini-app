// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/ReferralCollector.sol";

contract DeployCollectorScript is Script {
    function run() external returns (address collector) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address usdc = vm.envAddress("USDC");
        address megapot = vm.envAddress("MEGAPOT");
        address miner = vm.envAddress("MINER");
        address treasury = vm.envAddress("TREASURY");

        console.log("=== Deploying ReferralCollector ===");
        console.log("USDC:", usdc);
        console.log("Megapot:", megapot);
        console.log("Miner:", miner);
        console.log("Treasury:", treasury);

        vm.startBroadcast(deployerPrivateKey);

        ReferralCollector referralCollector = new ReferralCollector(usdc, megapot, miner, treasury);
        console.log("ReferralCollector:", address(referralCollector));

        vm.stopBroadcast();

        return address(referralCollector);
    }
}
