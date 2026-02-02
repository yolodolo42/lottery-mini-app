'use client'

import { useEffect, useState } from 'react'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt, useSwitchChain } from 'wagmi'
import { formatUnits } from 'viem'
import { ADDRESSES, LOTTERY_MINER_ABI, PAYOUT_CONSTANTS } from '@/lib/contracts'
import { useFarcasterProfile } from '@/hooks/useFarcasterProfile'
import { TARGET_CHAIN_ID } from '@/lib/wagmiConfig'

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000'

function formatAddress(addr: string): string {
  return `${addr.slice(0, 6)}...${addr.slice(-4)}`
}

function KingAvatar({ address, isYou }: { address: string; isYou: boolean }) {
  const { profile, isLoading } = useFarcasterProfile(isYou ? undefined : address)

  const avatarUrl = profile?.pfpUrl || `https://api.dicebear.com/7.x/shapes/svg?seed=${address}`
  const displayName = isYou ? 'You' : (profile?.displayName || profile?.username || formatAddress(address))
  const username = profile?.username

  return (
    <div className="flex items-center gap-3">
      <div className="rounded-full border-2 border-accent-border overflow-hidden">
        <img src={avatarUrl} alt={displayName} />
      </div>
      <div>
        <p className=" font-semibold text-primary">
          {isLoading ? 'Loading...' : displayName}
        </p>
        {username && !isYou && (
          <p className="text-sm text-accent-primary font-mono">@{username}</p>
        )}
        {isYou && (
          <p className="text-xs text-accent-primary font-mono">Current King</p>
        )}
      </div>
    </div>
  )
}

// v2: Payout indicator component
function PayoutIndicator({ elapsed }: { elapsed: number }) {
  const payoutBps = calculatePayoutBps(elapsed)
  const payoutPercent = (payoutBps / 100).toFixed(0)

  // Calculate progress for visual indicator (80% = full, 20% = minimal)
  const progressPercent = ((payoutBps - PAYOUT_CONSTANTS.MIN_BPS) / (PAYOUT_CONSTANTS.MAX_BPS - PAYOUT_CONSTANTS.MIN_BPS)) * 100

  return (
    <div className="mt-3 pt-3 border-t border-dashed border-accent-border">
      <div className="flex items-center justify-between mb-1">
        <span className="text-xs text-secondary font-mono">Payout if dethroned</span>
        <span className="text-xs font-mono text-accent-primary font-semibold">{payoutPercent}%</span>
      </div>
      <div className="h-1.5 bg-paper-dark rounded-full overflow-hidden">
        <div
          className="h-full bg-accent-primary transition-all duration-1000"
          style={{ width: `${progressPercent}%` }}
        />
      </div>
      <p className="text-xs text-muted mt-1 font-mono">
        {getPayoutPhaseLabel(elapsed)}
      </p>
    </div>
  )
}

function ClaimSection({ pendingEmissions, onClaimSuccess }: { pendingEmissions: bigint; onClaimSuccess: () => void }) {
  const { chainId: walletChainId, isConnected } = useAccount()
  const { writeContract: claim, data: claimHash, isPending: isClaiming } = useWriteContract()
  const { isLoading: isClaimConfirming, isSuccess: isClaimSuccess } = useWaitForTransactionReceipt({ hash: claimHash })
  const { switchChain, isPending: isSwitching } = useSwitchChain()

  const isChainLoading = isConnected && walletChainId === undefined
  const isWrongNetwork = isConnected && walletChainId !== undefined && walletChainId !== TARGET_CHAIN_ID

  useEffect(() => {
    if (isClaimSuccess) onClaimSuccess()
  }, [isClaimSuccess, onClaimSuccess])

  const isLoading = isClaiming || isClaimConfirming
  const formattedEmissions = Number(formatUnits(pendingEmissions, 18)).toLocaleString(undefined, { maximumFractionDigits: 0 })

  function handleClaim(): void {
    claim({
      chainId: TARGET_CHAIN_ID,
      address: ADDRESSES.LOTTERY_MINER,
      abi: LOTTERY_MINER_ABI,
      functionName: 'claimEmissions',
    })
  }

  if (isChainLoading) {
    return <button disabled className="btn btn-primary w-full opacity-50">Detecting network...</button>
  }

  if (isWrongNetwork) {
    return (
      <button
        onClick={() => switchChain({ chainId: TARGET_CHAIN_ID })}
        disabled={isSwitching}
        className="btn btn-primary w-full"
      >
        {isSwitching ? 'Switching...' : 'Switch Network'}
      </button>
    )
  }

  return (
    <div className="mt-4">
      <div className="flex items-center justify-between mb-3">
        <span className="label">Claimable</span>
        <span className="font-mono text-accent-primary font-semibold">{formattedEmissions} $LOTTERY</span>
      </div>
      <button
        onClick={handleClaim}
        disabled={isLoading || pendingEmissions === 0n}
        className="btn btn-primary w-full"
      >
        {isLoading ? 'Claiming...' : 'Claim Emissions'}
      </button>
    </div>
  )
}

export function KingStatus() {
  const { address } = useAccount()
  const [timeElapsed, setTimeElapsed] = useState(0)

  // For smooth emissions display: base from contract + interpolation
  const [baseEmissions, setBaseEmissions] = useState(0n)
  const [lastFetchTime, setLastFetchTime] = useState(Date.now())
  const [interpolatedSeconds, setInterpolatedSeconds] = useState(0)

  const { data: kingInfo, refetch: refetchKingInfo } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'getKingInfo',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const { data: currentPrice } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'getCurrentPrice',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const { data: lastBidTime } = useReadContract({
    address: ADDRESSES.LOTTERY_MINER,
    abi: LOTTERY_MINER_ABI,
    functionName: 'lastBidTime',
    query: { staleTime: 5000, refetchInterval: 10000 },
  })

  const [currentKing, reignStartTime, contractPendingEmissions, currentBid] = kingInfo ?? [undefined, 0n, 0n, 0n]
  const isKing = address && currentKing && address.toLowerCase() === currentKing.toLowerCase()
  const hasKing = currentKing && currentKing !== ZERO_ADDRESS

  // Sync base emissions when contract data changes (including after claims)
  useEffect(() => {
    if (contractPendingEmissions !== undefined) {
      setBaseEmissions(contractPendingEmissions)
      setLastFetchTime(Date.now())
      setInterpolatedSeconds(0)
    }
  }, [contractPendingEmissions])

  // Smooth interpolation timer (1 second updates)
  useEffect(() => {
    if (!isKing) return

    const interval = setInterval(() => {
      setInterpolatedSeconds(Math.floor((Date.now() - lastFetchTime) / 1000))
    }, 1000)
    return () => clearInterval(interval)
  }, [lastFetchTime, isKing])

  // Reign timer (for display only, uses reignStartTime which never resets)
  useEffect(() => {
    if (!reignStartTime || reignStartTime === 0n) return

    const updateTime = (): void => {
      setTimeElapsed(Math.floor(Date.now() / 1000) - Number(reignStartTime))
    }

    updateTime()
    const interval = setInterval(updateTime, 1000)
    return () => clearInterval(interval)
  }, [reignStartTime])

  if (!hasKing) {
    return (
      <div className="card text-center py-6">
        <h2 className=" font-semibold text-lg text-primary mb-1">No King Yet</h2>
        <p className="text-sm text-secondary">Be the first to claim the throne</p>
      </div>
    )
  }

  // Pending emissions: contract base + smooth interpolation
  // Cap at 7 days max (matching contract logic)
  const MAX_EMISSION_TOKENS = BigInt(7 * 24 * 60 * 60) * BigInt(10 ** 18)
  const interpolatedEmissions = BigInt(interpolatedSeconds) * BigInt(10 ** 18)
  const rawPendingEmissions = baseEmissions + interpolatedEmissions
  const pendingEmissions = rawPendingEmissions > MAX_EMISSION_TOKENS ? MAX_EMISSION_TOKENS : rawPendingEmissions

  const priceFormatted = currentPrice ? Number(formatUnits(currentPrice, 6)).toFixed(2) : '0'
  const bidFormatted = currentBid ? Number(formatUnits(currentBid, 6)).toFixed(2) : '0'

  // v2: Calculate elapsed time since last bid for payout indicator
  const payoutElapsed = lastBidTime ? Math.floor(Date.now() / 1000) - Number(lastBidTime) : 0

  // Format time for display
  const hours = Math.floor(timeElapsed / 3600)
  const minutes = Math.floor((timeElapsed % 3600) / 60)
  const seconds = timeElapsed % 60
  const timeDisplay = hours > 0
    ? `${hours}h ${minutes}m`
    : minutes > 0
      ? `${minutes}m ${seconds}s`
      : `${seconds}s`

  return (
    <div className="card">
      {/* Header row */}
      <div className="flex items-center justify-between mb-4">
        <span className=" font-bold text-lg tracking-wide">KING</span>
        <div className="rounded-full border-2 border-accent-border overflow-hidden w-10 h-10">
          <img
            src={`https://api.dicebear.com/7.x/shapes/svg?seed=${currentKing}`}
            alt="King"
          />
        </div>
      </div>

      {/* King info */}
      <KingAvatar address={currentKing} isYou={isKing ?? false} />

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-2 mt-4 pt-4 border-t border-dashed border-accent-border">
        <div className="stat">
          <p className="stat-label">Reign</p>
          <p className="font-mono text-sm text-primary">{timeDisplay}</p>
        </div>
        <div className="stat">
          <p className="stat-label">Bid</p>
          <p className="font-mono text-sm text-primary">${bidFormatted}</p>
        </div>
        <div className="stat">
          <p className="stat-label">Dethrone</p>
          <p className="font-mono text-sm text-accent-primary">${priceFormatted}</p>
        </div>
      </div>

      {/* v2: Payout indicator for non-King users */}
      {!isKing && payoutElapsed > 0 && (
        <PayoutIndicator elapsed={payoutElapsed} />
      )}

      {/* Claim section for King */}
      {isKing && (
        <ClaimSection pendingEmissions={pendingEmissions} onClaimSuccess={() => refetchKingInfo()} />
      )}
    </div>
  )
}

// v2: Calculate payout BPS based on elapsed time
function calculatePayoutBps(elapsed: number): number {
  if (elapsed <= PAYOUT_CONSTANTS.PHASE_1_END) {
    return PAYOUT_CONSTANTS.MAX_BPS
  }

  if (elapsed <= PAYOUT_CONSTANTS.PHASE_2_END) {
    const phaseElapsed = elapsed - PAYOUT_CONSTANTS.PHASE_1_END
    const phaseDuration = PAYOUT_CONSTANTS.PHASE_2_END - PAYOUT_CONSTANTS.PHASE_1_END
    const bpsDecay = PAYOUT_CONSTANTS.MAX_BPS - PAYOUT_CONSTANTS.MID_BPS
    return PAYOUT_CONSTANTS.MAX_BPS - Math.floor((bpsDecay * phaseElapsed) / phaseDuration)
  }

  if (elapsed <= PAYOUT_CONSTANTS.PHASE_3_END) {
    const phaseElapsed = elapsed - PAYOUT_CONSTANTS.PHASE_2_END
    const phaseDuration = PAYOUT_CONSTANTS.PHASE_3_END - PAYOUT_CONSTANTS.PHASE_2_END
    const bpsDecay = PAYOUT_CONSTANTS.MID_BPS - PAYOUT_CONSTANTS.MIN_BPS
    return PAYOUT_CONSTANTS.MID_BPS - Math.floor((bpsDecay * phaseElapsed) / phaseDuration)
  }

  return PAYOUT_CONSTANTS.MIN_BPS
}

// v2: Get human-readable payout phase label
function getPayoutPhaseLabel(elapsed: number): string {
  if (elapsed <= PAYOUT_CONSTANTS.PHASE_1_END) {
    return 'Max payout (first hour)'
  }
  if (elapsed <= PAYOUT_CONSTANTS.PHASE_2_END) {
    return 'Decreasing (1-6 hours)'
  }
  if (elapsed <= PAYOUT_CONSTANTS.PHASE_3_END) {
    return 'Decreasing (6-24 hours)'
  }
  return 'Floor payout (24h+)'
}
