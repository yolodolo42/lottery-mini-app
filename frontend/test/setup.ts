import '@testing-library/jest-dom'
import { vi } from 'vitest'

// Mock Farcaster SDK
vi.mock('@farcaster/miniapp-sdk', () => ({
  sdk: {
    actions: {
      ready: vi.fn(),
    },
    context: undefined,
  },
}))

// Mock next/navigation
vi.mock('next/navigation', () => ({
  useRouter: () => ({
    push: vi.fn(),
    replace: vi.fn(),
    prefetch: vi.fn(),
  }),
  useSearchParams: () => ({
    get: vi.fn(),
  }),
  usePathname: () => '/',
}))
