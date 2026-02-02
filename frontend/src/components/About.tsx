'use client'

export function About() {
  return (
    <div className="space-y-4">
      {/* Header */}
      <div className="text-center mb-4">
        <h2 className="heading text-2xl mb-1">$LOTTERY</h2>
        <p className="text-secondary">
          King of the Hill meets DeFi
        </p>
      </div>

      {/* How it works */}
      <div className="card">
        <h3 className="font-semibold mb-3 text-primary">How Mining Works</h3>
        <ul className="text-base text-secondary space-y-3 leading-relaxed">
          <li className="flex gap-3">
            <span className="text-accent-primary font-bold">1.</span>
            <span>Bid USDC to become the <strong className="text-primary">King</strong></span>
          </li>
          <li className="flex gap-3">
            <span className="text-accent-primary font-bold">2.</span>
            <span>While King, earn <strong className="text-primary">1 $LOTTERY per second</strong></span>
          </li>
          <li className="flex gap-3">
            <span className="text-accent-primary font-bold">3.</span>
            <span>Someone outbids you? You get <strong className="text-primary">20-80%</strong> of their bid</span>
          </li>
          <li className="flex gap-3">
            <span className="text-accent-primary font-bold">4.</span>
            <span>Claim your $LOTTERY tokens anytime</span>
          </li>
        </ul>
      </div>

      {/* Price Decay */}
      <div className="card">
        <h3 className="font-semibold mb-3 text-primary">3-Phase Price Decay</h3>
        <p className="text-base text-secondary mb-3 leading-relaxed">
          The price to dethrone the King decays over time:
        </p>
        <ul className="text-base text-secondary space-y-2 font-mono">
          <li>• <strong className="text-primary">Phase A</strong> (0-1h): 2x → 1.1x last bid</li>
          <li>• <strong className="text-primary">Phase B</strong> (1-24h): 1.1x → 1 USDC</li>
          <li>• <strong className="text-primary">Floor</strong> (24h+): Always 1 USDC</li>
        </ul>
      </div>

      {/* Payout Decay */}
      <div className="card">
        <h3 className="font-semibold mb-3 text-primary">Time-Decaying Payout</h3>
        <p className="text-base text-secondary mb-3 leading-relaxed">
          The longer you reign, the less you get when dethroned:
        </p>
        <ul className="text-base text-secondary space-y-2 font-mono">
          <li>• <strong className="text-primary">0-1h</strong>: 80% payout</li>
          <li>• <strong className="text-primary">1-6h</strong>: 80% → 60%</li>
          <li>• <strong className="text-primary">6-24h</strong>: 60% → 20%</li>
          <li>• <strong className="text-primary">24h+</strong>: 20% floor</li>
        </ul>
      </div>

      {/* Fee Split */}
      <div className="card">
        <h3 className="font-semibold mb-3 text-primary">Revenue Split</h3>
        <div className="space-y-2 border-b border-dotted border-accent-border pb-3 mb-3">
          <div className="flex justify-between text-base">
            <span className="text-secondary">Previous King</span>
            <span className="font-bold text-primary font-mono">20-80%</span>
          </div>
          <div className="flex justify-between text-base">
            <span className="text-secondary">Creator</span>
            <span className="font-bold text-primary font-mono">5%</span>
          </div>
          <div className="flex justify-between text-base">
            <span className="text-secondary">Treasury</span>
            <span className="font-bold text-primary font-mono">15-75%</span>
          </div>
        </div>
        <p className="text-sm text-muted font-mono">
          Treasury = remainder after king + creator. Longer reigns = more to treasury.
        </p>
      </div>

      {/* Links */}
      <div className="card">
        <h3 className="font-semibold mb-3 text-primary">Contracts</h3>
        <div className="space-y-2">
          <a
            href="https://sepolia.basescan.org/address/0x757f0cbBb7be9aaaEdFAB04632e4293BB4e0a73E"
            target="_blank"
            rel="noopener noreferrer"
            className="flex justify-between text-sm text-secondary hover:text-primary transition-colors font-mono"
          >
            <span>Miner</span>
            <span>→</span>
          </a>
          <a
            href="https://sepolia.basescan.org/address/0x329fDa672F359c8422a790Df4e2BEBd96453C096"
            target="_blank"
            rel="noopener noreferrer"
            className="flex justify-between text-sm text-secondary hover:text-primary transition-colors font-mono"
          >
            <span>$LOTTERY Token</span>
            <span>→</span>
          </a>
          <a
            href="https://sepolia.basescan.org/address/0x1E389cf75155E34A8901388a70c4c1B1d94e0333"
            target="_blank"
            rel="noopener noreferrer"
            className="flex justify-between text-sm text-secondary hover:text-primary transition-colors font-mono"
          >
            <span>Treasury</span>
            <span>→</span>
          </a>
        </div>
      </div>

      {/* Footer */}
      <div className="text-center pt-4">
        <p className="text-xs text-muted font-mono">
          EST. 2026 • FARCASTER • BASE SEPOLIA
        </p>
      </div>
    </div>
  )
}
