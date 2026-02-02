import { http, createConfig } from 'wagmi'
import { baseSepolia, mainnet, base, sepolia } from 'wagmi/chains'
import { farcasterMiniApp } from '@farcaster/miniapp-wagmi-connector'
import { injected } from 'wagmi/connectors'

// Target chain for this app
export const TARGET_CHAIN = baseSepolia
export const TARGET_CHAIN_ID = baseSepolia.id

// Dev wallet connector for local testing (MetaMask)
// In production (Warpcast), only Farcaster connector is used
//
// IMPORTANT: We include common chains (mainnet, base, sepolia) in the config
// so wagmi can properly detect when the wallet is on the wrong network.
// Without these, chainId from useAccount() may be undefined when on other chains,
// which breaks wrong-network detection.
export const config = createConfig({
  chains: [baseSepolia, mainnet, base, sepolia],
  transports: {
    [baseSepolia.id]: http(),
    [mainnet.id]: http(),
    [base.id]: http(),
    [sepolia.id]: http(),
  },
  connectors: [injected(), farcasterMiniApp()],
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}
