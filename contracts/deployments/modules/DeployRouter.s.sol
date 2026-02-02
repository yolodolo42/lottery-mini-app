// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/MegapotRouter.sol";

contract DeployRouterScript is Script {
    function run() external returns (address router) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        address usdc = vm.envAddress("USDC");
        address megapot = vm.envAddress("MEGAPOT");
        address collector = vm.envAddress("COLLECTOR");

        console.log("=== Deploying MegapotRouter ===");
        console.log("USDC:", usdc);
        console.log("Megapot:", megapot);
        console.log("ReferralCollector:", collector);

        vm.startBroadcast(deployerPrivateKey);

        MegapotRouter megapotRouter = new MegapotRouter(usdc, megapot, collector);
        console.log("MegapotRouter:", address(megapotRouter));

        vm.stopBroadcast();

        return address(megapotRouter);
    }
}
