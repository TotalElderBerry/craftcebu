import assert from 'node:assert/strict'
import { before, test } from 'node:test'
import { asServiceRole, asUser, makeProduct, makeUser, newDb } from './harness.mjs'

let db
before(async () => {
  db = await newDb()
})

const add = (userId, productId, qty) =>
  asUser(db, userId, async () => (await db.query('select public.add_to_cart($1, $2) as qty', [productId, qty])).rows[0].qty)

const cartRows = async userId =>
  (await db.query('select product_id, qty from public.cart_items where profile_id = $1', [userId])).rows

test('add_to_cart inserts then accumulates', async () => {
  const user = await makeUser(db)
  const product = await makeProduct(db, { stock: 5 })
  assert.equal(await add(user, product, 2), 2)
  assert.equal(await add(user, product, 2), 4)
})

test('add_to_cart clamps to stock', async () => {
  const user = await makeUser(db)
  const product = await makeProduct(db, { stock: 3 })
  await add(user, product, 2)
  assert.equal(await add(user, product, 5), 3)
  assert.deepEqual(await cartRows(user), [{ product_id: product, qty: 3 }])
})

test('add_to_cart rejects sold out', async () => {
  const user = await makeUser(db)
  const product = await makeProduct(db, { stock: 0 })
  await assert.rejects(add(user, product, 1), /sold_out/)
})

test('add_to_cart rejects inactive and unverified', async () => {
  const user = await makeUser(db)
  await assert.rejects(add(user, await makeProduct(db, { isActive: false }), 1), /not_available/)
  await assert.rejects(add(user, await makeProduct(db, { artisanStatus: 'pending' }), 1), /not_available/)
})

test('add_to_cart rejects qty below 1', async () => {
  const user = await makeUser(db)
  const product = await makeProduct(db)
  await assert.rejects(add(user, product, 0), /invalid_qty/)
})

test('anon cannot call add_to_cart', async () => {
  const product = await makeProduct(db)
  await assert.rejects(add(null, product, 1), /permission denied/)
})

test('users only see and change their own cart', async () => {
  const a = await makeUser(db)
  const b = await makeUser(db)
  const product = await makeProduct(db)
  const other = await makeProduct(db)
  await add(a, product, 1)
  await asUser(db, b, async () => {
    assert.equal((await db.query('select * from public.cart_items where profile_id = $1', [a])).rows.length, 0)
    assert.equal((await db.query('update public.cart_items set qty = 2 where profile_id = $1', [a])).affectedRows, 0)
    assert.equal((await db.query('delete from public.cart_items where profile_id = $1', [a])).affectedRows, 0)
    await assert.rejects(db.query('insert into public.cart_items (profile_id, product_id, qty) values ($1, $2, 1)', [a, other]))
  })
  assert.deepEqual(await cartRows(a), [{ product_id: product, qty: 1 }])
})

test('deleting a product removes cart rows', async () => {
  const user = await makeUser(db)
  const product = await makeProduct(db)
  await add(user, product, 1)
  await asServiceRole(db, () => db.query('delete from public.products where id = $1', [product]))
  assert.equal((await cartRows(user)).length, 0)
})
