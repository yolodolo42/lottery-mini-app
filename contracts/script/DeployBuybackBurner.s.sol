// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/BuybackBurner.sol";
import "../src/LotteryTreasury.sol";

/// @title DeployBuybackBurner
/// @notice Deploys BuybackBurner and configures Treasury
contract DeployBuybackBurnerScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        address usdc = vm.envAddress("USDC");
        address lpToken = vm.envAddress("LP_TOKEN");
        address treasury = vm.envAddress("TREASURY");

        console.log("========================================");
        console.log("      DEPLOY BUYBACK BURNER             ");
        console.log("========================================");
        console.log("Deployer:", deployer);
        console.log("USDC:", usdc);
        console.log("LP Token:", lpToken);
        console.log("Treasury:", treasury);
        console.log("========================================\n");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy BuybackBurner
        console.log("--- Deploying BuybackBurner ---");
        BuybackBurner burner = new BuybackBurner(
            usdc,
            lpToken,
            deployer,      // owner
            24 hours,      // epochPeriod
            12000,         // priceMultiplier (1.2x)
            1e6,           // minInitPrice (1 USDC per LP)
            10e6           // initPrice (10 USDC per LP)
        );
        console.log("BuybackBurner:", address(burner));

        // Configure Treasury
        console.log("--- Configuring Treasury ---");
        LotteryTreasury(treasury).setBuybackBurner(address(burner));
        console.log("Treasury.setBuybackBurner done");

        vm.stopBroadcast();

        console.log("========================================");
        console.log("         DEPLOYMENT COMPLETE            ");
        console.log("========================================");
        console.log("BuybackBurner:", address(burner));
        console.log("========================================");
    }
}
