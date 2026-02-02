'use client'

import { useState, useEffect } from 'react'
import { useAccount, useReadContract, useSwitchChain } from 'wagmi'
import { formatUnits, parseUnits } from 'viem'
import { ADDRESSES, LOTTERY_MINER_ABI, USDC_ABI, DECAY_CONSTANTS } from '@/lib/contracts'
import { TARGET_CHAIN_ID } from '@/lib/wagmiConfig'
import { useBatchedTransaction, encodeApproveCall, encodeContractCall, type Call } from '@/hooks/useBatchedTransaction'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'
const DEADLINE_SECONDS = 300 // 5 minutes

export function MineButton() {
  const { address, chainId: walletChainId, isConnected } = useAccount()
  const { switchChain, isPending: isSwitching } = useSwitchChain()
  const { execute, state, error: batchError, reset } = useBatchedTransaction()

  const isChainLoading = isConnected && walletChainId === undefined
  const isWrongNetwork = isConnected && walletChainId !== undefined && walletChainId !== TARGET_CHAIN_ID

  const [bidAmount, setBidAmount] = useState('')
  const [now, setNow] = useState(() => Math.floor(Date.now() / 1000))

  // Update time every second for decay countdown
  useEffect(() => {
    const interval = setInterval(() => setNow(Math.floor(Date.now() / 1000)), 1000)
    return () => clearInterval(interval)
  }, [])

  // Reset batch state on success
  useEffect(() => {
    if (state === 'success') {
      setBidAmount('')
      refetchMinBid()
      refetchAllowance()
      // Reset after a short delay to allow UI to update
      const timeout = setTimeout(() => reset(), 2000)
      return () => clearTimeout(timeout)
    }
  }, [state])

  const { data: kingInfo } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'getKingInfo',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const [currentKing] = kingInfo ?? [undefined]
  const isKing = address && currentKing && currentKing !== ZERO_ADDRESS && address.toLowerCase() === currentKing.toLowerCase()

  // v2: Read epochId for MEV protection
  const { data: epochId } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'epochId',
    query: { staleTime: 2000, refetchInterval: 5000 },
  })

  // v2: Read lastBidTime for decay calculation
  const { data: lastBidTime } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'lastBidTime',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const { data: minimumBid, refetch: refetchMinBid } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'getMinimumBid',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const { data: currentPrice } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'getCurrentPrice',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: ADDRESSES.USDC,
    abi: USDC_ABI,
    functionName: 'allowance',
    args: address ? [address, ADDRESSES.LOTTERY_MINER] : undefined,
  })

  const { data: usdcBalance } = useReadContract({
    address: ADDRESSES.USDC,
    abi: USDC_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
    query: { staleTime: 5000, refetchInterval: 15000 },
  })

  const bidAmountWei = bidAmount ? parseUnits(bidAmount, 6) : 0n
  const needsApproval = allowance !== undefined && bidAmountWei > allowance
  const insufficientBalance = usdcBalance !== undefined && bidAmountWei > usdcBalance
  const belowMinimum = minimumBid !== undefined && bidAmountWei > 0n && bidAmountWei < minimumBid
  const isLoading = state === 'pending' || state === 'confirming'

  const currentPriceFormatted = currentPrice ? Number(formatUnits(currentPrice, 6)).toFixed(2) : '0'
  const minBidFormatted = minimumBid ? Number(formatUnits(minimumBid, 6)).toFixed(2) : '0'
  const balanceFormatted = usdcBalance ? Number(formatUnits(usdcBalance, 6)).toLocaleString() : '0'

  // v2: Calculate decay phase and time remaining
  const elapsed = lastBidTime ? now - Number(lastBidTime) : 0

  // Batched dethrone: approve (if needed) + mine in single transaction
  function handleDethrone(): void {
    if (epochId === undefined) return

    const deadline = BigInt(Math.floor(Date.now() / 1000) + DEADLINE_SECONDS)
    const calls: Call[] = []

    // Add approval if needed
    if (needsApproval) {
      calls.push(encodeApproveCall(
        ADDRESSES.USDC,
        ADDRESSES.LOTTERY_MINER,
        bidAmountWei
      ))
    }

    // Always add mine call
    calls.push(encodeContractCall(
      ADDRESSES.LOTTERY_MINER,
      LOTTERY_MINER_ABI,
      'mine',
      [bidAmountWei, epochId, deadline]
    ))

    execute(calls)
  }

  function setMinBid(): void {
    if (minimumBid) setBidAmount(formatUnits(minimumBid, 6))
  }

  // Don't show mine section if user is already King
  if (isKing) {
    return (
      <div className="card text-center py-4">
        <p className="text-secondary text-sm ">
          You are the King! Collect your earnings above.
        </p>
      </div>
    )
  }

  // Button text based on state
  function getButtonText(): string {
    if (state === 'pending') return 'Confirming...'
    if (state === 'confirming') return 'Processing...'
    if (state === 'success') return 'Success!'
    if (needsApproval) return 'Approve & Dethrone'
    return 'Dethrone'
  }

  return (
    <div className="space-y-3">
      {/* Mining form */}
      <div className="card space-y-5">
        {/* Header */}
        <div>
          <h3 className="font-bold text-lg text-primary mb-3">Dethrone the King</h3>
          <div className="flex items-center justify-between text-sm">
            <span className="text-secondary">Current price:</span>
            <span className="font-mono font-semibold text-primary">${currentPriceFormatted}</span>
          </div>
        </div>

        <div className="divider" />

        {/* Bid amount */}
        <div>
          <div className="flex items-center justify-between mb-3">
            <span className="text-sm font-semibold text-primary">Your Bid</span>
            <button onClick={setMinBid} className="text-xs text-accent-primary hover:opacity-70 font-mono transition-opacity">
              Min: ${minBidFormatted}
            </button>
          </div>
          <div className="relative">
            <input
              type="text"
              inputMode="decimal"
              value={bidAmount}
              onChange={(e) => {
                const val = e.target.value
                if (val === '' || /^\d*\.?\d*$/.test(val)) setBidAmount(val)
              }}
              placeholder="0.00"
              className="input font-mono pr-16"
            />
            <span className="absolute right-4 top-1/2 -translate-y-1/2 text-sm text-muted font-mono">USDC</span>
          </div>
          <div className="flex items-center justify-between mt-3">
            <span className="text-xs text-muted font-mono">Balance: {balanceFormatted}</span>
            {belowMinimum && <span className="text-xs text-red-600 font-mono">Below minimum</span>}
            {insufficientBalance && <span className="text-xs text-red-600 font-mono">Insufficient</span>}
          </div>
        </div>

        {/* Error */}
        {(batchError || state === 'error') && (
          <div className="p-3 border-2 border-red-600 bg-red-50">
            <p className="text-xs text-red-600 font-mono">{batchError?.message?.slice(0, 100) || 'Transaction failed'}</p>
          </div>
        )}

        {/* Action button */}
        {isChainLoading ? (
          <button disabled className="btn w-full opacity-50">Detecting network...</button>
        ) : isWrongNetwork ? (
          <button
            onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })}
            disabled={isSwitching}
            className="btn w-full"
          >
            {isSwitching ? 'Switching...' : 'Switch Network'}
          </button>
        ) : (
          <button
            onClick={handleDethrone}
            disabled={isLoading || !bidAmount || belowMinimum || insufficientBalance || epochId === undefined || state === 'success'}
            className="btn btn-primary w-full"
          >
            {getButtonText()}
          </button>
        )}
      </div>
    </div>
  )
}

// v2: Helper to determine current decay phase
function getDecayPhase(elapsed: number): string | null {
  if (elapsed < DECAY_CONSTANTS.PHASE_A_END) {
    return 'Phase A'
  } else if (elapsed < DECAY_CONSTANTS.PHASE_B_END) {
    return 'Phase B'
  } else {
    return 'Floor'
  }
}

// v2: Helper to format time until next phase
function getTimeToNextPhase(elapsed: number): string {
  let remaining: number

  if (elapsed < DECAY_CONSTANTS.PHASE_A_END) {
    remaining = DECAY_CONSTANTS.PHASE_A_END - elapsed
  } else if (elapsed < DECAY_CONSTANTS.PHASE_B_END) {
    remaining = DECAY_CONSTANTS.PHASE_B_END - elapsed
  } else {
    return '' // At floor, no next phase
  }

  const hours = Math.floor(remaining / 3600)
  const minutes = Math.floor((remaining % 3600) / 60)
  const seconds = remaining % 60

  if (hours > 0) {
    return `${hours}h ${minutes}m`
  } else if (minutes > 0) {
    return `${minutes}m ${seconds}s`
  } else {
    return `${seconds}s`
  }
}
