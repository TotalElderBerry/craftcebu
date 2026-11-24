// One-time setup: make an existing account the CRAFTCEBU owner.
//
//   1. Sign up through the app with the owner's email.
//   2. node --env-file=.env.local scripts/promote-owner.mjs owner@example.com
//
// Needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local. The service
// role key bypasses RLS, so it must never get a VITE_ prefix (that would ship
// it to the browser).
import { createClient } from '@supabase/supabase-js'

const email = process.argv[2]?.trim().toLowerCase()
const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env

if (!email) {
  console.error('Usage: node --env-file=.env.local scripts/promote-owner.mjs <email>')
  process.exit(1)
}
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local')
  process.exit(1)
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

async function findUserByEmail(target) {
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 })
    if (error) throw error
    const user = data.users.find((u) => u.email?.toLowerCase() === target)
    if (user) return user
    if (data.users.length < 200) return null
  }
}

const user = await findUserByEmail(email)
if (!user) {
  console.error(`No account found for ${email}. Sign up in the app first.`)
  process.exit(1)
}

const { data: existing } = await admin.from('profiles').select('id').eq('role', 'owner').maybeSingle()
if (existing && existing.id !== user.id) {
  console.error('Another account is already the owner. CRAFTCEBU allows one owner.')
  process.exit(1)
}

const { error } = await admin.from('profiles').update({ role: 'owner' }).eq('id', user.id)
if (error) {
  console.error('Could not promote:', error.message)
  process.exit(1)
}
console.log(`${email} is now the CRAFTCEBU owner.`)
