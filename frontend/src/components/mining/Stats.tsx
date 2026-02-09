'use client'

import { useAccount, useReadContract } from 'wagmi'
import { formatUnits } from 'viem'
import { ADDRESSES, LOTTERY_TOKEN_ABI, USDC_ABI } from '@/lib/contracts'
import { FlipDigit } from '@/components/ui/FlipDigit'

function formatTokenAmount(amount: bigint | undefined, decimals: number): string {
  if (!amount) return '0'
  return Number(formatUnits(amount, decimals)).toLocaleString(undefined, {
    maximumFractionDigits: 0,
  })
}

function formatTokenNumber(amount: bigint | undefined, decimals: number): number {
  if (!amount) return 0
  return Math.floor(Number(formatUnits(amount, decimals)))
}

export function Stats() {
  const { address } = useAccount()

  const { data: tokenBalance } = useReadContract({
    address: ADDRESSES.LOTTERY_TOKEN,
    abi: LOTTERY_TOKEN_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })

  const { data: usdcBalance } = useReadContract({
    address: ADDRESSES.USDC,
    abi: USDC_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })

  const lotteryBalance = formatTokenNumber(tokenBalance, 18)
  const usdcBalanceNum = formatTokenNumber(usdcBalance, 6)

  return (
    <div className="card space-y-3">
      {/* $LOTTERY balance */}
      <div className="flex items-center justify-between">
        <p className="stat-label">$LOTTERY</p>
        <FlipDigit value={lotteryBalance} digits={5} size="sm" />
      </div>

      {/* USDC balance */}
      <div className="flex items-center justify-between">
        <p className="stat-label">USDC</p>
        <FlipDigit value={usdcBalanceNum} digits={5} size="sm" />
      </div>
    </div>
  )
}
