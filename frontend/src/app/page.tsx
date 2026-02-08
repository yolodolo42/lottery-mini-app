'use client'

import { useState, useEffect } from 'react'
import dynamic from 'next/dynamic'
import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { KingStatus } from '@/components/mining/KingStatus'
import { MineButton } from '@/components/mining/MineButton'
import { Stats } from '@/components/mining/Stats'
import { useFarcasterUser } from '@/hooks/useFarcasterUser'

// Dynamic imports for non-critical tabs (code splitting)
const Treasury = dynamic(() => import('@/components/Treasury').then(mod => ({ default: mod.Treasury })), {
  loading: () => <LoadingSkeleton title="TREASURY" />,
})

const About = dynamic(() => import('@/components/About').then(mod => ({ default: mod.About })), {
  loading: () => <LoadingSkeleton title="ABOUT" />,
})

// Loading skeleton for dynamic imports
function LoadingSkeleton({ title }: { title: string }) {
  return (
    <div className="space-y-4 animate-fade-in-up">
      <div className="text-center mb-4">
        <h2 className="font-serif font-bold text-2xl tracking-wide mb-1">{title}</h2>
        <div className="h-4 animate-shimmer rounded w-48 mx-auto" />
      </div>
      <div className="ticket-stub-dotted">
        <div className="space-y-3">
          <div className="h-4 animate-shimmer rounded w-full" />
          <div className="h-4 animate-shimmer rounded w-3/4" style={{ animationDelay: '0.1s' }} />
          <div className="h-4 animate-shimmer rounded w-1/2" style={{ animationDelay: '0.2s' }} />
        </div>
      </div>
    </div>
  )
}

type Tab = 'mine' | 'treasury' | 'about'

function ConnectScreen() {
  const { connect, connectors } = useConnect()

  // Inside Warpcast: only show Farcaster connector
  const fcConnector = connectors.find(c => c.id === 'farcasterMiniApp')
  const visibleConnectors = fcConnector ? [fcConnector] : connectors

  return (
    <main className="min-h-screen flex flex-col items-center justify-center p-6">
      <div className="card max-w-sm w-full">
        <div className="text-center mb-8">
          <h1 className="text-5xl font-bold mb-3 bg-gradient-to-r from-amber-500 to-amber-600 bg-clip-text text-transparent">
            LOTTERY
          </h1>
          <p className="text-secondary">
            Compete to be the King. Earn tokens.
          </p>
        </div>

        <div className="card mb-6 bg-paper-dark">
          <div className="grid grid-cols-2 gap-4">
            <div className="stat">
              <p className="stat-label">Earn Rate</p>
              <p className="stat-value">1/sec</p>
            </div>
            <div className="stat">
              <p className="stat-label">Token</p>
              <p className="stat-value">$LOTTERY</p>
            </div>
          </div>
        </div>

        <div className="space-y-3">
          {visibleConnectors.map((connector) => (
            <button
              key={connector.id}
              onClick={() => connect({ connector })}
              className={connector.name === 'Farcaster'
                ? 'btn btn-primary w-full'
                : 'btn w-full'}
            >
              {connector.name === 'Injected' ? 'Connect Wallet' : `Connect with ${connector.name}`}
            </button>
          ))}
        </div>

        <p className="text-center text-xs text-muted mt-6 font-mono">
          EST. 2026
        </p>
      </div>
    </main>
  )
}

function LoadingScreen() {
  return (
    <main className="min-h-screen flex flex-col items-center justify-center p-4">
      <div className="text-center animate-fade-in-up">
        <h1 className="text-4xl font-bold mb-4 bg-gradient-to-r from-amber-500 to-amber-600 bg-clip-text text-transparent">
          LOTTERY
        </h1>
        <div className="flex items-center justify-center gap-1">
          <span className="text-secondary">Loading</span>
          <span className="flex gap-1">
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" />
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" style={{ animationDelay: '0.2s' }} />
            <span className="w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse" style={{ animationDelay: '0.4s' }} />
          </span>
        </div>
      </div>
    </main>
  )
}

function UserPill({ address }: { address: string }) {
  const user = useFarcasterUser()
  const { disconnect } = useDisconnect()

  const displayName = user?.username ? `@${user.username}` : `${address.slice(0, 6)}...${address.slice(-4)}`
  const avatarUrl = user?.pfpUrl || `https://api.dicebear.com/7.x/shapes/svg?seed=${address}`

  return (
    <div className="flex items-center gap-2">
      <div className="badge">
        <img src={avatarUrl} alt={displayName} className="w-6 h-6 rounded-full border border-accent-border" />
        <span className="text-xs font-mono">{displayName}</span>
      </div>
      <button onClick={() => {
        disconnect()
        localStorage.removeItem('wagmi.store')
        localStorage.removeItem('wagmi.connected')
        localStorage.removeItem('wagmi.wallet')
      }} className="p-1.5 hover:bg-paper-dark rounded transition-colors" title="Disconnect">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" className="text-muted hover:text-red-500">
          <path d="M18.36 6.64a9 9 0 1 1-12.73 0" />
          <line x1="12" y1="2" x2="12" y2="12" />
        </svg>
      </button>
    </div>
  )
}

function BottomNav({ activeTab, setActiveTab }: { activeTab: Tab; setActiveTab: (tab: Tab) => void }) {
  return (
    <nav className="nav mt-4 -mx-5 -mb-5">
      <button
        onClick={() => setActiveTab('mine')}
        className={`nav-item ${activeTab === 'mine' ? 'active' : ''}`}
      >
        Mine
      </button>
      <button
        onClick={() => setActiveTab('treasury')}
        className={`nav-item ${activeTab === 'treasury' ? 'active' : ''}`}
      >
        Treasury
      </button>
      <button
        onClick={() => setActiveTab('about')}
        className={`nav-item ${activeTab === 'about' ? 'active' : ''}`}
      >
        About
      </button>
    </nav>
  )
}

function Dashboard({ address }: { address: string }) {
  const [activeTab, setActiveTab] = useState<Tab>('mine')

  return (
    <main className="min-h-screen p-4">
      <div className="max-w-md mx-auto">
        {/* Main card */}
        <div className="card p-6">
          {/* Header */}
          <header className="flex items-center justify-between mb-6">
            <h1 className="text-2xl font-bold bg-gradient-to-r from-amber-500 to-amber-600 bg-clip-text text-transparent">
              LOTTERY
            </h1>
            <UserPill address={address} />
          </header>

          <div className="divider" />

          {/* Tab content */}
          <div className="mt-4">
            {activeTab === 'mine' && (
              <div className="space-y-4 stagger-children">
                <KingStatus />
                <div className="divider-dotted" />
                <div className="flex gap-4">
                  <div className="flex-1">
                    <MineButton />
                  </div>
                  <Stats />
                </div>
              </div>
            )}
            {activeTab === 'treasury' && (
              <div className="max-h-[50vh] overflow-y-auto -mx-1 px-1 pb-4">
                <Treasury />
              </div>
            )}
            {activeTab === 'about' && (
              <div className="max-h-[50vh] overflow-y-auto -mx-1 px-1 pb-4">
                <About />
              </div>
            )}
          </div>

          {/* Navigation */}
          <BottomNav activeTab={activeTab} setActiveTab={setActiveTab} />
        </div>
      </div>
    </main>
  )
}

export default function Home() {
  const [mounted, setMounted] = useState(false)
  const { address, isConnected } = useAccount()
  const { connect, connectors } = useConnect()

  useEffect(() => {
    setMounted(true)
  }, [])

  // Auto-connect Farcaster wallet when inside Warpcast
  useEffect(() => {
    if (!mounted || isConnected) return
    const fc = connectors.find(c => c.id === 'farcasterMiniApp')
    if (fc) {
      connect({ connector: fc })
    }
  }, [mounted, isConnected, connectors, connect])

  if (!mounted) {
    return <LoadingScreen />
  }

  if (!isConnected || !address) {
    return <ConnectScreen />
  }

  return <Dashboard address={address} />
}
