import assert from 'node:assert/strict'
import { before, test } from 'node:test'
import { asUser, makeProduct, makeUser, newDb } from './harness.mjs'

let db
before(async () => {
  db = await newDb()
})

test('migrations load', () => {
  assert.ok(db)
})

test('anon sees only active products from verified shops', async () => {
  const visible = await makeProduct(db)
  const inactive = await makeProduct(db, { isActive: false })
  const pending = await makeProduct(db, { artisanStatus: 'pending' })
  const ids = await asUser(db, null, async () => (await db.query('select id from public.products')).rows.map(r => r.id))
  assert.ok(ids.includes(visible))
  assert.ok(!ids.includes(inactive))
  assert.ok(!ids.includes(pending))
})

test('buyer cannot read another buyer\'s wishlist', async () => {
  const a = await makeUser(db)
  const b = await makeUser(db)
  const product = await makeProduct(db)
  await db.query('insert into public.wishlists (profile_id, product_id) values ($1, $2)', [a, product])
  const rows = await asUser(db, b, async () => (await db.query('select * from public.wishlists where profile_id = $1', [a])).rows)
  assert.equal(rows.length, 0)
})
