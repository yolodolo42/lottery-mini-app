'use client'

import { useEffect, useState } from 'react'
import sdk from '@farcaster/miniapp-sdk'

interface FarcasterUser {
  fid: number
  username?: string
  displayName?: string
  pfpUrl?: string
}

export function useFarcasterUser(): FarcasterUser | null {
  const [user, setUser] = useState<FarcasterUser | null>(null)

  useEffect(() => {
    sdk.context.then((context) => {
      if (context?.user) {
        setUser({
          fid: context.user.fid,
          username: context.user.username,
          displayName: context.user.displayName,
          pfpUrl: context.user.pfpUrl,
        })
      }
    })
  }, [])

  return user
}
