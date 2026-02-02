'use client'

import { useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import { ADDRESSES, LOTTERY_TREASURY_ABI, USDC_ABI } from '@/lib/contracts'
import { FlipDigit } from '@/components/ui/FlipDigit'

export function Treasury() {
  const { data: poolBalances } = useReadContract({
    address: ADDRESSES.LOTTERY_TREASURY,
    abi: LOTTERY_TREASURY_ABI,
    functionName: 'getPoolBalances',
    query: { staleTime: 5000, refetchInterval: 15000 },
  })

  const { data: treasuryUsdcBalance } = useReadContract({
    address: ADDRESSES.USDC,
    abi: USDC_ABI,
    functionName: 'balanceOf',
    args: [ADDRESSES.LOTTERY_TREASURY],
    query: { staleTime: 5000, refetchInterval: 15000 },
  })

  const { data: totalTickets } = useReadContract({
    address: ADDRESSES.LOTTERY_TREASURY,
    abi: LOTTERY_TREASURY_ABI,
    functionName: 'totalTicketsPurchased',
    query: { staleTime: 5000, refetchInterval: 15000 },
  })

  const [megapotPool, reservePool] = poolBalances ?? [0n, 0n]
  const megapotNum = Math.floor(Number(formatUnits(megapotPool, 6)))
  const reserveNum = Math.floor(Number(formatUnits(reservePool, 6)))
  const totalNum = treasuryUsdcBalance ? Math.floor(Number(formatUnits(treasuryUsdcBalance, 6))) : 0
  const ticketsNum = totalTickets ? Number(totalTickets) : 0

  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="text-center mb-4">
        <h2 className="heading text-2xl mb-1">TREASURY</h2>
        <p className="text-secondary">
          15% of all bids flow here
        </p>
      </div>

      {/* Total tickets purchased */}
      <div className="card text-center">
        <p className="stat-label mb-2">Megapot Tickets Purchased</p>
        <div className="flex items-center justify-center gap-1">
          <FlipDigit value={ticketsNum} digits={6} size="lg" />
        </div>
        <p className="text-xs text-muted mt-2 font-mono">Auto-purchased on each dethrone</p>
      </div>

      {/* Pool balances */}
      <div className="card">
        <div className="grid grid-cols-2 gap-4 mb-4">
          <div className="stat">
            <p className="stat-label">Megapot Pool</p>
            <div className="flex items-center justify-center gap-1">
              <span className="text-accent-primary font-mono">$</span>
              <FlipDigit value={megapotNum} digits={4} size="sm" />
            </div>
            <p className="text-xs text-muted mt-1">Pending tickets</p>
          </div>
          <div className="stat">
            <p className="stat-label">Reserve Pool</p>
            <div className="flex items-center justify-center gap-1">
              <span className="text-secondary font-mono">$</span>
              <FlipDigit value={reserveNum} digits={4} size="sm" />
            </div>
            <p className="text-xs text-muted mt-1">Protocol reserve</p>
          </div>
        </div>

        <div className="divider" />

        <div className="stat">
          <p className="stat-label">Total Treasury</p>
          <div className="flex items-center justify-center gap-1">
            <span className="text-primary font-mono text-lg">$</span>
            <FlipDigit value={totalNum} digits={5} size="md" />
          </div>
        </div>
      </div>

      {/* How it works */}
      <div className="card">
        <p className="text-base text-primary mb-2 font-semibold">How it works:</p>
        <ul className="text-sm text-secondary space-y-1 font-mono leading-relaxed">
          <li>• 10% of bids → Megapot tickets (auto)</li>
          <li>• 5% of bids → Reserve pool</li>
          <li>• Referral fees split: 50% King / 50% Treasury</li>
          <li>• If Megapot wins, prize goes to treasury</li>
        </ul>
      </div>

      {/* Contract link */}
      <div className="text-center">
        <p className="text-xs text-muted font-mono">
          Treasury: {ADDRESSES.LOTTERY_TREASURY.slice(0, 6)}...{ADDRESSES.LOTTERY_TREASURY.slice(-4)}
        </p>
      </div>
    </div>
  )
}
