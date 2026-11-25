import { readdir, readFile } from 'node:fs/promises'
import { PGlite } from '@electric-sql/pglite'

const supabaseDir = new URL('../', import.meta.url)

// A fresh database with Supabase stand-ins, every migration and the seed.
export async function newDb() {
  const db = new PGlite()
  await db.exec(await readFile(new URL('tests/stubs.sql', supabaseDir), 'utf8'))
  const migrations = (await readdir(new URL('migrations/', supabaseDir))).filter(f => f.endsWith('.sql')).sort()
  for (const file of migrations) {
    try {
      await db.exec(await readFile(new URL(`migrations/${file}`, supabaseDir), 'utf8'))
    }
    catch (error) {
      error.message = `${file}: ${error.message}`
      throw error
    }
  }
  await db.exec(await readFile(new URL('seed.sql', supabaseDir), 'utf8'))
  return db
}

// Runs fn as a signed-in user (or anon when userId is null), like a request
// through the Supabase API, then switches back to the superuser.
export async function asUser(db, userId, fn) {
  await db.exec(`set role ${userId ? 'authenticated' : 'anon'}`)
  await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [userId ?? ''])
  try {
    return await fn()
  }
  finally {
    await db.exec(`reset role; select set_config('request.jwt.claim.sub', '', false)`)
  }
}

export async function asServiceRole(db, fn) {
  await db.exec('set role service_role')
  try {
    return await fn()
  }
  finally {
    await db.exec('reset role')
  }
}

let counter = 0

export async function makeUser(db, { email = `user${++counter}@test.local`, role } = {}) {
  const { rows } = await db.query(`insert into auth.users (email, raw_user_meta_data) values ($1, '{"full_name":"Test"}') returning id`, [email])
  if (role) await db.query(`update public.profiles set role = $1 where id = $2`, [role, rows[0].id])
  return rows[0].id
}

export async function makeProduct(db, { stock = 5, isActive = true, artisanStatus = 'verified' } = {}) {
  const n = ++counter
  const owner = await makeUser(db, { role: 'artisan' })
  const { rows: [artisan] } = await db.query(
    `insert into public.artisans (profile_id, shop_name, slug, status) values ($1, $2, $3, $4) returning id`,
    [owner, `Shop ${n}`, `shop-${n}`, artisanStatus],
  )
  const { rows: [product] } = await db.query(
    `insert into public.products (artisan_id, name, slug, price, stock, is_active) values ($1, $2, $3, 100, $4, $5) returning id`,
    [artisan.id, `Piece ${n}`, `piece-${n}`, stock, isActive],
  )
  return product.id
}
