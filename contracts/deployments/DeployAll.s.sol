// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Script.sol";
import "../src/LotteryToken.sol";
import "../src/LotteryMiner.sol";
import "../src/LotteryTreasury.sol";
import "../src/MegapotRouter.sol";
import "../src/ReferralCollector.sol";
import "../src/BuybackBurner.sol";
import "./modules/DeployMocks.s.sol";

/// @title DeployAll
/// @notice Deploys all lottery contracts with optional testnet mocks
/// @dev Usage:
///   Testnet: TESTNET=true forge script deployments/DeployAll.s.sol --rpc-url $RPC --broadcast
///   Mainnet: forge script deployments/DeployAll.s.sol --rpc-url $RPC --broadcast
contract DeployAllScript is Script {
    // Base Mainnet addresses
    address constant MAINNET_USDC = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant MAINNET_MEGAPOT = 0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95;

    // Base Sepolia addresses (real Megapot testnet)
    address constant SEPOLIA_USDC = 0xA4253E7C13525287C56550b8708100f93E60509f;
    address constant SEPOLIA_MEGAPOT = 0x6f03c7BCaDAdBf5E6F5900DA3d56AdD8FbDac5De;

    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        bool isTestnet = vm.envOr("TESTNET", false);

        address creator = vm.envOr("CREATOR", deployer);
        address owner = vm.envOr("OWNER", deployer);

        console.log("========================================");
        console.log("         LOTTERY V2 DEPLOYMENT          ");
        console.log("========================================");
        console.log("Network:", isTestnet ? "TESTNET" : "MAINNET");
        console.log("Deployer:", deployer);
        console.log("Creator (5% fee):", creator);
        console.log("Owner:", owner);
        console.log("========================================\n");

        address usdc;
        address megapot;

        vm.startBroadcast(deployerPrivateKey);

        // Step 1: Resolve USDC and Megapot addresses
        if (isTestnet) {
            bool useMocks = vm.envOr("USE_MOCKS", false);
            if (useMocks) {
                console.log("--- Step 1: Deploying Mocks ---");
                MockUSDC mockUsdc = new MockUSDC();
                MockMegapot mockMegapot = new MockMegapot(address(mockUsdc));
                mockUsdc.mint(deployer, 100_000e6);

                usdc = address(mockUsdc);
                megapot = address(mockMegapot);

                console.log("MockUSDC:", usdc);
                console.log("MockMegapot:", megapot);
                console.log("Minted 100,000 USDC to deployer\n");
            } else {
                console.log("--- Step 1: Using Real Base Sepolia Addresses ---");
                usdc = SEPOLIA_USDC;
                megapot = SEPOLIA_MEGAPOT;
                console.log("MPUSDC:", usdc);
                console.log("Megapot:", megapot);
                console.log("");
            }
        } else {
            console.log("--- Step 1: Using Mainnet Addresses ---");
            usdc = MAINNET_USDC;
            megapot = MAINNET_MEGAPOT;
            console.log("USDC:", usdc);
            console.log("Megapot:", megapot);
            console.log("");
        }

        // Step 2: Deploy LotteryToken
        console.log("--- Step 2: Deploying LotteryToken ---");
        LotteryToken token = new LotteryToken();
        console.log("LotteryToken:", address(token));
        console.log("");

        // Step 3: Deploy LotteryTreasury
        console.log("--- Step 3: Deploying LotteryTreasury ---");
        LotteryTreasury treasury = new LotteryTreasury(usdc, megapot, owner);
        console.log("LotteryTreasury:", address(treasury));
        console.log("");

        // Step 4: Deploy LotteryMiner
        console.log("--- Step 4: Deploying LotteryMiner ---");
        LotteryMiner miner = new LotteryMiner(usdc, address(token), creator, address(treasury));
        console.log("LotteryMiner:", address(miner));
        console.log("");

        // Step 5: Deploy ReferralCollector (needs miner)
        console.log("--- Step 5: Deploying ReferralCollector ---");
        ReferralCollector collector = new ReferralCollector(usdc, megapot, address(miner), address(treasury));
        console.log("ReferralCollector:", address(collector));
        console.log("");

        // Step 6: Deploy MegapotRouter (needs collector)
        console.log("--- Step 6: Deploying MegapotRouter ---");
        MegapotRouter router = new MegapotRouter(usdc, megapot, address(collector));
        console.log("MegapotRouter:", address(router));
        console.log("");

        // Step 7: Deploy BuybackBurner (optional - requires LP token)
        BuybackBurner burner;
        try vm.envAddress("LP_TOKEN") returns (address lpToken) {
            console.log("--- Step 7: Deploying BuybackBurner ---");
            burner = new BuybackBurner(
                usdc,
                lpToken,
                owner,
                24 hours,  // epochPeriod
                12000,     // priceMultiplier (1.2x)
                1e6,       // minInitPrice (1 USDC per LP)
                10e6       // initPrice (10 USDC per LP)
            );
            console.log("BuybackBurner:", address(burner));
            console.log("");
        } catch {
            console.log("--- Step 7: Skipping BuybackBurner (LP_TOKEN not set) ---");
            console.log("Note: Create LOTTERY-USDC LP pair first, then deploy BuybackBurner separately");
            console.log("");
        }

        // Step 8: Configure contracts
        console.log("--- Step 8: Configuring Contracts ---");

        token.setMiner(address(miner));
        console.log("Token.setMiner done");

        treasury.setMiner(address(miner));
        console.log("Treasury.setMiner done");

        treasury.setMegapotRouter(address(router));
        console.log("Treasury.setMegapotRouter done");

        if (address(burner) != address(0)) {
            treasury.setBuybackBurner(address(burner));
            console.log("Treasury.setBuybackBurner done");
        }
        console.log("");

        vm.stopBroadcast();

        // Print summary
        console.log("========================================");
        console.log("         DEPLOYMENT COMPLETE            ");
        console.log("========================================");
        console.log("USDC:              ", usdc);
        console.log("Megapot:           ", megapot);
        console.log("LotteryToken:      ", address(token));
        console.log("LotteryTreasury:   ", address(treasury));
        console.log("LotteryMiner:      ", address(miner));
        console.log("MegapotRouter:     ", address(router));
        console.log("ReferralCollector: ", address(collector));
        if (address(burner) != address(0)) {
            console.log("BuybackBurner:     ", address(burner));
        }
        console.log("========================================");
    }
}
