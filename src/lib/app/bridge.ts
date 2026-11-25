import type { AppSessionPayload } from './token'
import { needsFreshToken, parseSessionPayload } from './token'

// Inside the CraftCebu phone app the site runs in "app mode": the app owns
// the sign-in and lends the page short-lived access tokens, and the page
// hands product, shop and sign-in links to the app's native screens.

export type NativeMessage =
  | { type: 'ready' }
  | { type: 'needToken' }
  | { type: 'signOut' }
  | { type: 'login', returnTo: string }
  | { type: 'openProduct', slug: string }
  | { type: 'openShop', category?: string, town?: string, q?: string }
  | { type: 'cartChanged' }

interface AppHandlers {
  navigate: (path: string) => void
  reloadCart: () => void
}

declare global {
  interface Window {
    CraftCebuNative?: { postMessage: (message: string) => void }
    craftcebu?: {
      setSession: (payload: unknown) => void
      clearSession: () => void
      navigate: (path: string) => void
      reloadCart: () => void
    }
    __craftcebuSent?: NativeMessage[]
  }
}

// Development only: `localStorage.craftcebuFakeApp = '1'` turns on app mode
// in a desktop browser and records messages in window.__craftcebuSent.
function fakeAppFlag() {
  if (!import.meta.env.DEV) return false
  try {
    return localStorage.getItem('craftcebuFakeApp') === '1'
  }
  catch {
    return false
  }
}

const fakeApp = fakeAppFlag()
export const inApp = navigator.userAgent.includes('CraftCebuApp') || fakeApp

const TOKEN_WAIT_MS = 5000

let current: AppSessionPayload | null = null
let received = false
const listeners = new Set<(session: AppSessionPayload | null) => void>()
let waiters: (() => void)[] = []

function receive(session: AppSessionPayload | null) {
  current = session
  received = true
  for (const cb of listeners) cb(session)
  const done = waiters
  waiters = []
  for (const resolve of done) resolve()
}

export function postToNative(msg: NativeMessage) {
  if (fakeApp) {
    (window.__craftcebuSent ??= []).push(msg)
    return
  }
  window.CraftCebuNative?.postMessage(JSON.stringify(msg))
}

// Calls back with every session the app sends, starting with the latest one
// if it has already arrived.
export function onAppSession(cb: (session: AppSessionPayload | null) => void) {
  listeners.add(cb)
  if (received) cb(current)
  return () => {
    listeners.delete(cb)
  }
}

// Resolves at the app's next setSession or clearSession, or after `ms`.
function nextSession(ms: number) {
  return new Promise<void>((resolve) => {
    const timer = setTimeout(resolve, ms)
    waiters.push(() => {
      clearTimeout(timer)
      resolve()
    })
  })
}

let refreshing: Promise<void> | null = null

// The supabase-js `accessToken` callback. A token that is about to expire is
// swapped for a fresh one from the app; the page never refreshes on its own.
export async function appAccessToken(): Promise<string | null> {
  if (!current) return null
  if (needsFreshToken(current.expires_at, Date.now() / 1000)) {
    if (!refreshing) {
      refreshing = nextSession(TOKEN_WAIT_MS).finally(() => {
        refreshing = null
      })
      postToNative({ type: 'needToken' })
    }
    await refreshing
  }
  return current?.access_token ?? null
}

export function installAppHandlers(handlers: AppHandlers) {
  window.craftcebu = {
    setSession: payload => receive(parseSessionPayload(payload)),
    clearSession: () => receive(null),
    navigate: path => handlers.navigate(path),
    reloadCart: () => handlers.reloadCart(),
  }
  postToNative({ type: 'ready' })
}
