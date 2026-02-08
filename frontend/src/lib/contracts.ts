import { Address } from 'viem'

// Base Sepolia testnet contract addresses (v5 - deployed 2026-02-08)
// Points at real Megapot + MPUSDC on Base Sepolia
export const ADDRESSES = {
  USDC: '0xA4253E7C13525287C56550b8708100f93E60509f' as Address, // MPUSDC (real Base Sepolia)
  MEGAPOT: '0x6f03c7BCaDAdBf5E6F5900DA3d56AdD8FbDac5De' as Address, // Real Megapot (Base Sepolia)
  LOTTERY_TOKEN: '0x01Bfd7F444578Eb6Cd7D9F17DFbCFaa05C72f8df' as Address,
  LOTTERY_MINER: '0x6D6ac07A791Da43aAdE206b1Af9AFB64330CE1aA' as Address,
  LOTTERY_TREASURY: '0x8115E7E399cBeFd367D2C42e11D17dD515372b9A' as Address,
  MEGAPOT_ROUTER: '0x40520D266e75657C0e9A870C0870867EE1Dd476b' as Address,
  REFERRAL_COLLECTOR: '0xB9E92b004f4bF2E9C22e872a278a5075dFC9B5eE' as Address,
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
