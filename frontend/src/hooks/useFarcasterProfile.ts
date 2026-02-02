'use client'

import { useEffect, useState } from 'react'

interface FarcasterProfile {
  fid: number
  username: string | null
  displayName: string | null
  pfpUrl: string | null
}

export function useFarcasterProfile(address: string | undefined): {
  profile: FarcasterProfile | null
  isLoading: boolean
} {
  const [profile, setProfile] = useState<FarcasterProfile | null>(null)
  const [isLoading, setIsLoading] = useState(false)

  useEffect(() => {
    if (!address) {
      setProfile(null)
      return
    }

    setIsLoading(true)
    fetch(`/api/profile?address=${address}`)
      .then((res) => res.json())
      .then((data) => {
        setProfile(data)
        setIsLoading(false)
      })
      .catch(() => {
        setProfile(null)
        setIsLoading(false)
      })
  }, [address])

  return { profile, isLoading }
}
