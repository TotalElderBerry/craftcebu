import assert from 'node:assert/strict'
import { test } from 'node:test'
import { mergeGuestLines, removedNotice } from '../../src/lib/cartMerge.ts'

const line = (productId: string, qty = 1) => ({ productId, qty, name: `Piece ${productId}` })

test('merged and refused lines leave the guest cart', async () => {
  const keep = await mergeGuestLines([line('a'), line('b')], async (id) => {
    if (id === 'b') throw new Error('sold_out')
  })
  assert.deepEqual(keep, [])
})

test('lines that failed to merge stay for the next try', async () => {
  const keep = await mergeGuestLines([line('a'), line('b', 2), line('c')], async (id) => {
    if (id === 'b') throw new Error('Failed to fetch')
    if (id === 'c') throw new Error('not_available')
  })
  assert.deepEqual(keep, [line('b', 2)])
})

test('removed notice names dropped pieces and counts hidden ones', () => {
  assert.equal(removedNotice([], 0), null)
  assert.equal(removedNotice(['Banig'], 0), "Removed from your cart because they're no longer available: Banig")
  assert.equal(removedNotice([], 2), 'Removed 2 pieces from your cart because they\'re no longer available.')
  assert.equal(removedNotice(['Banig'], 1), "Removed from your cart because they're no longer available: Banig, and 1 more piece")
})
