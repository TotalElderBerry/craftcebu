// Pure helpers for the session the phone app lends the site. No imports, so
// `node --test` can load this file directly.

// Ask the app for a new token once the current one has a minute or less left.
export const TOKEN_MARGIN_SECONDS = 60

export interface AppSessionPayload {
  access_token: string
  expires_at: number
  user: { id: string, email?: string, user_metadata?: Record<string, unknown> }
}

export function needsFreshToken(expiresAt: number | null, nowSeconds: number, margin = TOKEN_MARGIN_SECONDS): boolean {
  return expiresAt == null || expiresAt - nowSeconds <= margin
}

const isRecord = (v: unknown): v is Record<string, unknown> => typeof v === 'object' && v !== null

// Keeps only the fields the site may hold. Anything else the app sends,
// above all a refresh token, is dropped so it never reaches the page.
export function parseSessionPayload(raw: unknown): AppSessionPayload | null {
  if (!isRecord(raw) || !isRecord(raw.user)) return null
  const { access_token, expires_at, user } = raw
  if (typeof access_token !== 'string' || typeof expires_at !== 'number' || typeof user.id !== 'string') return null
  const clean: AppSessionPayload['user'] = { id: user.id }
  if (typeof user.email === 'string') clean.email = user.email
  if (isRecord(user.user_metadata)) clean.user_metadata = user.user_metadata
  return { access_token, expires_at, user: clean }
}
