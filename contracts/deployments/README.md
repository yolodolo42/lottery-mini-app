# Lottery Deployment Scripts

Modular deployment system for Lottery v2 contracts.

## Contracts

| Contract | Purpose |
|----------|---------|
| `LotteryToken` | ERC20 with voting, minted by miner |
| `LotteryTreasury` | Fee routing, Megapot ticket purchases |
| `LotteryMiner` | King-of-the-hill bidding game |
| `MegapotRouter` | Routes ticket purchases with referral |
| `ReferralCollector` | Distributes referral fees (50% king, 50% treasury) |

## Deploy Order

```
1. Mocks (testnet only)
2. LotteryToken         (no deps)
3. LotteryTreasury      (needs USDC, Megapot)
4. LotteryMiner         (needs USDC, Token, Treasury)
5. ReferralCollector    (needs USDC, Megapot, Miner, Treasury)
6. MegapotRouter        (needs USDC, Megapot, Collector)

Post-deploy:
- Token.setMiner(miner)
- Treasury.setMiner(miner)
- Treasury.setMegapotRouter(router)
```

## Full Deployment

### Testnet (Base Sepolia)

Deploys mocks + all contracts + configures them:

```bash
PRIVATE_KEY=0x... TESTNET=true forge script deployments/DeployAll.s.sol \
  --rpc-url https://sepolia.base.org \
  --broadcast \
  -vvvv
```

### Mainnet (Base)

Uses real USDC and Megapot addresses:

```bash
PRIVATE_KEY=0x... forge script deployments/DeployAll.s.sol \
  --rpc-url $BASE_RPC_URL \
  --broadcast \
  -vvvv
```

## Individual Deployments

Deploy contracts one at a time (useful for upgrades or testing):

### Mocks (testnet)
```bash
PRIVATE_KEY=0x... forge script deployments/modules/DeployMocks.s.sol \
  --rpc-url https://sepolia.base.org --broadcast
```

### Token
```bash
PRIVATE_KEY=0x... forge script deployments/modules/DeployToken.s.sol \
  --rpc-url $RPC --broadcast
```

### Treasury
```bash
PRIVATE_KEY=0x... USDC=0x... MEGAPOT=0x... \
forge script deployments/modules/DeployTreasury.s.sol \
  --rpc-url $RPC --broadcast
```

### Miner
```bash
PRIVATE_KEY=0x... USDC=0x... TOKEN=0x... TREASURY=0x... \
forge script deployments/modules/DeployMiner.s.sol \
  --rpc-url $RPC --broadcast
```

### ReferralCollector
```bash
PRIVATE_KEY=0x... USDC=0x... MEGAPOT=0x... MINER=0x... TREASURY=0x... \
forge script deployments/modules/DeployCollector.s.sol \
  --rpc-url $RPC --broadcast
```

### MegapotRouter
```bash
PRIVATE_KEY=0x... USDC=0x... MEGAPOT=0x... COLLECTOR=0x... \
forge script deployments/modules/DeployRouter.s.sol \
  --rpc-url $RPC --broadcast
```

## Post-Deploy Configuration

If you deployed contracts individually, link them:

```bash
PRIVATE_KEY=0x... TOKEN=0x... TREASURY=0x... MINER=0x... ROUTER=0x... \
forge script deployments/Configure.s.sol \
  --rpc-url $RPC --broadcast
```

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `PRIVATE_KEY` | Yes | Deployer private key |
| `TESTNET` | No | Set to `true` for testnet deployment |
| `CREATOR` | No | Address receiving 5% creator fee (default: deployer) |
| `OWNER` | No | Treasury owner address (default: deployer) |

## Addresses

### Base Mainnet
- USDC: `0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`
- Megapot: `0xbEDd4F2beBE9E3E636161E644759f3cbe3d51B95`

### Base Sepolia (after testnet deploy)
Check console output or broadcast files for deployed addresses.

## Verification

After deployment, verify contracts on BaseScan:

```bash
forge verify-contract <ADDRESS> <CONTRACT_NAME> \
  --chain-id 8453 \
  --etherscan-api-key $BASESCAN_API_KEY
```
