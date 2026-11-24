import type { Session } from '@supabase/supabase-js'
import type { Profile, UserRole } from '@/types/database'
import { defineStore } from 'pinia'
import { computed, ref } from 'vue'
import { toast } from 'vue-sonner'
import { isSupabaseConfigured, supabase } from '@/lib/supabase'

export const useAuthStore = defineStore('auth', () => {
  const session = ref<Session | null>(null)
  const profile = ref<Profile | null>(null)
  const ready = ref(false)

  const user = computed(() => session.value?.user ?? null)
  const role = computed<UserRole | null>(() => profile.value?.role ?? null)
  const isOwner = computed(() => role.value === 'owner')
  const isArtisan = computed(() => role.value === 'artisan')

  async function loadProfile() {
    if (!session.value) {
      profile.value = null
      return
    }
    const { data, error } = await supabase
      .from('profiles')
      .select('*')
      .eq('id', session.value.user.id)
      .single()
    if (error) console.error('Could not load profile', error)
    if (data?.is_banned) {
      await supabase.auth.signOut()
      session.value = null
      profile.value = null
      toast.error('This account has been suspended. Email hello@craftcebu.test if you think this is a mistake.')
      return
    }
    profile.value = data
  }

  let initPromise: Promise<void> | null = null

  // Resolves once the first session and profile are known, so route guards
  // can wait for it instead of redirecting a signed-in user to /login.
  function init() {
    if (initPromise) return initPromise
    initPromise = (async () => {
      if (isSupabaseConfigured) {
        const { data } = await supabase.auth.getSession()
        session.value = data.session
        await loadProfile()
        supabase.auth.onAuthStateChange((_event, newSession) => {
          session.value = newSession
          // Supabase warns against awaiting other calls inside this callback.
          setTimeout(loadProfile, 0)
        })
      }
      ready.value = true
    })()
    return initPromise
  }

  async function signIn(email: string, password: string) {
    const { data, error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) throw error
    session.value = data.session
    await loadProfile()
    if (!session.value) throw new Error('This account has been suspended.')
  }

  // Returns true when the account needs email confirmation before signing in.
  async function signUp(fullName: string, email: string, password: string) {
    const { data, error } = await supabase.auth.signUp({
      email,
      password,
      options: { data: { full_name: fullName } },
    })
    if (error) throw error
    session.value = data.session
    await loadProfile()
    return !data.session
  }

  async function signOut() {
    await supabase.auth.signOut()
    session.value = null
    profile.value = null
  }

  async function sendPasswordReset(email: string) {
    const { error } = await supabase.auth.resetPasswordForEmail(email, {
      redirectTo: `${window.location.origin}/reset-password`,
    })
    if (error) throw error
  }

  async function updatePassword(password: string) {
    const { error } = await supabase.auth.updateUser({ password })
    if (error) throw error
  }

  return {
    session, profile, ready, user, role, isOwner, isArtisan,
    init, loadProfile, signIn, signUp, signOut, sendPasswordReset, updatePassword,
  }
})
