import { NextRequest, NextResponse } from 'next/server'

const HUB_URL = 'https://hub.pinata.cloud/v1'

interface UserData {
  fid: number
  username: string | null
  displayName: string | null
  pfpUrl: string | null
}

// Simple in-memory cache (resets on redeploy)
const cache = new Map<string, { data: UserData | null; timestamp: number }>()
const CACHE_TTL = 5 * 60 * 1000 // 5 minutes

export async function GET(request: NextRequest): Promise<NextResponse> {
  const address = request.nextUrl.searchParams.get('address')

  if (!address) {
    return NextResponse.json({ error: 'Address required' }, { status: 400 })
  }

  const normalizedAddress = address.toLowerCase()

  // Check cache
  const cached = cache.get(normalizedAddress)
  if (cached && Date.now() - cached.timestamp < CACHE_TTL) {
    return NextResponse.json(cached.data)
  }

  try {
    // Step 1: Get FID(s) that verified this address
    const verificationsRes = await fetch(
      `${HUB_URL}/verificationsByAddress?address=${normalizedAddress}`
    )

    if (!verificationsRes.ok) {
      cache.set(normalizedAddress, { data: null, timestamp: Date.now() })
      return NextResponse.json(null)
    }

    const verificationsData = await verificationsRes.json()
    const messages = verificationsData.messages || []

    if (messages.length === 0) {
      cache.set(normalizedAddress, { data: null, timestamp: Date.now() })
      return NextResponse.json(null)
    }

    // Get the first FID that verified this address
    const fid = messages[0]?.data?.fid
    if (!fid) {
      cache.set(normalizedAddress, { data: null, timestamp: Date.now() })
      return NextResponse.json(null)
    }

    // Step 2: Get user data for this FID
    const userData = await fetchUserData(fid)

    cache.set(normalizedAddress, { data: userData, timestamp: Date.now() })
    return NextResponse.json(userData)
  } catch (error) {
    console.error('Error fetching profile:', error)
    return NextResponse.json({ error: 'Failed to fetch profile' }, { status: 500 })
  }
}

async function fetchUserData(fid: number): Promise<UserData> {
  const userData: UserData = {
    fid,
    username: null,
    displayName: null,
    pfpUrl: null,
  }

  // Fetch all user data types in parallel
  const [usernameRes, displayNameRes, pfpRes] = await Promise.all([
    fetch(`${HUB_URL}/userDataByFid?fid=${fid}&user_data_type=6`), // USERNAME
    fetch(`${HUB_URL}/userDataByFid?fid=${fid}&user_data_type=2`), // DISPLAY
    fetch(`${HUB_URL}/userDataByFid?fid=${fid}&user_data_type=1`), // PFP
  ])

  if (usernameRes.ok) {
    const data = await usernameRes.json()
    userData.username = data.messages?.[0]?.data?.userDataBody?.value || null
  }

  if (displayNameRes.ok) {
    const data = await displayNameRes.json()
    userData.displayName = data.messages?.[0]?.data?.userDataBody?.value || null
  }

  if (pfpRes.ok) {
    const data = await pfpRes.json()
    userData.pfpUrl = data.messages?.[0]?.data?.userDataBody?.value || null
  }

  return userData
}
