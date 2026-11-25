import { createClient } from '@supabase/supabase-js'
import { appAccessToken, inApp } from '@/lib/app/bridge'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

// Lets the app render a setup notice instead of crashing before .env.local exists.
export const isSupabaseConfigured = Boolean(url && anonKey)

// In the phone app, requests carry the token the app lends us. That option
// also switches off supabase.auth, so the page can never spend the app's
// refresh token.
export const supabase = createClient(
  url || 'http://localhost:54321',
  anonKey || 'missing-anon-key',
  inApp ? { accessToken: appAccessToken } : undefined,
)
