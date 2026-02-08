import { Address } from 'viem'

// Base Sepolia testnet contract addresses (v4 - deployed 2026-01-31)
// Includes 5% premine for LP, BuybackBurner active
export const ADDRESSES = {
  USDC: '0x17e0491422685c309bFB6aDAF662c2832b41eF4E' as Address, // MockUSDC
  MEGAPOT: '0xe7a6A816DD03d71e858D40B952721063ff83B53A' as Address, // MockMegapot
  LOTTERY_TOKEN: '0x10117dF540d74A9595Fa08F56426bb3C28FF22c9' as Address,
  LOTTERY_MINER: '0xAFD683F33cBdC83790BCf73eA6D44582eB9d935F' as Address,
  LOTTERY_TREASURY: '0xDB689D685F34A6335Ae12b042953fC9f9db73003' as Address,
  MEGAPOT_ROUTER: '0xd820D03ace8E62cAE633Aa5A2a75786BFC65AA8e' as Address,
  BUYBACK_BURNER: '0x035b0cE12bAA3cF4A32C8AC467f7A70Cb38894Aa' as Address,
  LP_TOKEN: '0x49b04ED2133e6aA890650542b8C03b5426E844f0' as Address, // LOTTERY-USDC LP on Uniswap V2
} as const

// v2: Decay phase constants (matching contract)
export const DECAY_CONSTANTS = {
  PHASE_A_END: 3600,      // 1 hour in seconds
  PHASE_B_END: 86400,     // 24 hours in seconds
  MIN_BID_ABS: 10000000n,  // 10 USDC (6 decimals)
} as const

// v2: Payout phase constants
export const PAYOUT_CONSTANTS = {
  PHASE_1_END: 3600,      // 1 hour
  PHASE_2_END: 21600,     // 6 hours
  PHASE_3_END: 86400,     // 24 hours
  MAX_BPS: 8000,          // 80%
  MID_BPS: 6000,          // 60%
  MIN_BPS: 2000,          // 20%
} as const

export const USDC_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
] as const

export const LOTTERY_TOKEN_ABI = [
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'totalSupply',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'MAX_TOTAL_SUPPLY',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const

export const LOTTERY_MINER_ABI = [
  // v2: Updated mine function with MEV protection
  {
    name: 'mine',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'bidAmount', type: 'uint256' },
      { name: '_epochId', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'claimEmissions',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [],
    outputs: [],
  },
  // v2: epochId for MEV protection
  {
    name: 'epochId',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'king',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'kingStartTime',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'reignStartTime',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'lastBidAmount',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'lastBidTime',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getCurrentPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getMinimumBid',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getPendingEmissions',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getKingInfo',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'currentKing', type: 'address' },
      { name: 'startTime', type: 'uint256' },
      { name: 'pendingEmissions', type: 'uint256' },
      { name: 'currentBid', type: 'uint256' },
    ],
  },
  {
    name: 'EMISSION_RATE',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  // v2: Pause status
  {
    name: 'paused',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'pausedAt',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  // v2: Decay phase constants
  {
    name: 'DECAY_PHASE_A_END',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'DECAY_PHASE_B_END',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'MIN_BID_ABS',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const

export const LOTTERY_TREASURY_ABI = [
  {
    name: 'getPoolBalances',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: 'megapot_', type: 'uint256' },
      { name: 'reserve_', type: 'uint256' },
    ],
  },
  {
    name: 'megapotBps',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'totalTicketsPurchased',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const


// Phase 4: BuybackBurner ABI
export const BUYBACK_BURNER_ABI = [
  {
    name: 'buy',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'lpAmount', type: 'uint256' },
      { name: '_epochId', type: 'uint256' },
      { name: 'deadline', type: 'uint256' },
      { name: 'maxUsdcExpected', type: 'uint256' },
    ],
    outputs: [],
  },
  {
    name: 'getCurrentPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'epochId',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'usdcAccumulated',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'totalLpBurned',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'initPrice',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'startTime',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'epochPeriod',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'getAuctionState',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [
      { name: '_epochId', type: 'uint256' },
      { name: '_currentPrice', type: 'uint256' },
      { name: '_initPrice', type: 'uint256' },
      { name: '_startTime', type: 'uint256' },
      { name: '_usdcAccumulated', type: 'uint256' },
      { name: '_totalLpBurned', type: 'uint256' },
    ],
  },
] as const

// ERC20 LP Token ABI (for approvals and balance checks)
export const LP_TOKEN_ABI = [
  {
    name: 'approve',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'spender', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [{ type: 'bool' }],
  },
  {
    name: 'allowance',
    type: 'function',
    stateMutability: 'view',
    inputs: [
      { name: 'owner', type: 'address' },
      { name: 'spender', type: 'address' },
    ],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'balanceOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'account', type: 'address' }],
    outputs: [{ type: 'uint256' }],
  },
  {
    name: 'totalSupply',
    type: 'function',
    stateMutability: 'view',
    inputs: [],
    outputs: [{ type: 'uint256' }],
  },
] as const
