# $LOTTERY Frontend

Farcaster Mini App for the $LOTTERY King-of-the-Hill game on Base.

---

## Tech Stack

- **Next.js 16** (App Router, Turbopack)
- **Tailwind CSS 4** (Vintage 1920s lottery ticket aesthetic)
- **wagmi** - Ethereum React hooks
- **@farcaster/miniapp-sdk** - Farcaster integration
- **viem** - Ethereum interactions

---

## Features

### Core Functionality
- King status dashboard with decay timers
- Mining (bidding) with MEV protection (epochId + deadline)
- Real-time price decay display (3-phase Dutch auction)
- Payout decay indicator (80%→20% over 24h)
- Treasury stats (Megapot tickets, pool balances)
- Farcaster authentication & user profiles

### Performance
- Self-hosted fonts (next/font)
- Code splitting (dynamic imports for Treasury/About)
- Optimized React Query (staleTime + refetchInterval)
- Bundle optimization (optimizePackageImports)

### Design
- Vintage 1920s lottery ticket aesthetic
- Art deco frames and decorations
- Flip-digit animations
- Paper texture and dot-matrix separators
- Responsive for Farcaster mini app frame

---

## Development

### Install
```bash
npm install
```

### Run Dev Server
```bash
npm run dev
```

Open http://localhost:3000

### Build
```bash
npm run build
```

### Deploy to Vercel
```bash
vercel --prod
```

---

## Contract Integration

Contracts on Base Sepolia (see `src/lib/contracts.ts`):

```typescript
export const ADDRESSES = {
  LOTTERY_MINER: '0x757f0cbBb7be9aaaEdFAB04632e4293BB4e0a73E',
  LOTTERY_TOKEN: '0x329fDa672F359c8422a790Df4e2BEBd96453C096',
  LOTTERY_TREASURY: '0x1E389cf75155E34A8901388a70c4c1B1d94e0333',
  // ...
}
```

---

## Farcaster Mini App

### Configuration

- **Manifest:** `public/.well-known/farcaster.json`
- **Images:** icon.png, splash.png, og-image.png
- **Meta tags:** Frame metadata in `src/app/layout.tsx`

### Testing

1. **Local debugger:**
   ```bash
   npm install -g @frames.js/debugger@latest
   frames  # Opens at localhost:3010
   ```

2. **Warpcast debugger:**
   - Go to https://farcaster.xyz/~/developers/
   - Enter production URL
   - Test in Warpcast

3. **Cloudflare tunnel** (for local testing):
   ```bash
   brew install cloudflared
   cloudflared tunnel --url http://localhost:3000
   ```

---

## Project Structure

```
src/
├── app/
│   ├── layout.tsx         # Root layout, fonts, metadata
│   ├── page.tsx           # Main page with tabs
│   ├── providers.tsx      # Wagmi + Farcaster SDK providers
│   └── globals.css        # Tailwind + vintage styles
├── components/
│   ├── mining/
│   │   ├── KingStatus.tsx    # Current king display
│   │   ├── MineButton.tsx    # Bidding interface
│   │   └── Stats.tsx         # User stats (balance, emissions)
│   ├── Treasury.tsx       # Treasury stats
│   ├── About.tsx          # How it works
│   └── ui/
│       └── FlipDigit.tsx  # Animated flip numbers
├── hooks/
│   └── useFarcasterUser.ts  # Farcaster profile data
└── lib/
    ├── contracts.ts       # Contract addresses & ABIs
    └── wagmiConfig.ts     # Wagmi + Farcaster config
```

---

## Environment Variables

None required for frontend (uses public RPC).

Contracts are on Base Sepolia testnet.

---

## Learn More

- Farcaster Frames: https://docs.farcaster.xyz/developers/frames/v2/
- wagmi: https://wagmi.sh/
- Next.js: https://nextjs.org/docs
