// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../../src/BuybackBurner.sol";

contract DeployBuybackScript is Script {
    function run() external returns (address burner) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address usdc = vm.envAddress("USDC");
        address lpToken = vm.envAddress("LP_TOKEN");
        address owner = vm.envOr("OWNER", deployer);

        // Default parameters
        uint256 epochPeriod = 24 hours;
        uint256 priceMultiplier = 12000; // 1.2x
        uint256 minInitPrice = 1e6; // 1 USDC per 1e18 LP
        uint256 initPrice = 10e6; // 10 USDC per 1e18 LP

        console.log("=== Deploying BuybackBurner ===");
        console.log("USDC:", usdc);
        console.log("LP Token:", lpToken);
        console.log("Owner:", owner);
        console.log("Epoch Period:", epochPeriod);
        console.log("Price Multiplier:", priceMultiplier);
        console.log("Min Init Price:", minInitPrice);
        console.log("Init Price:", initPrice);

        vm.startBroadcast(deployerPrivateKey);

        BuybackBurner buybackBurner = new BuybackBurner(
            usdc,
            lpToken,
            owner,
            epochPeriod,
            priceMultiplier,
            minInitPrice,
            initPrice
        );
        console.log("BuybackBurner:", address(buybackBurner));

        vm.stopBroadcast();

        return address(buybackBurner);
    }
}
