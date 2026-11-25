import assert from 'node:assert/strict'
import { test } from 'node:test'
import { needsFreshToken, parseSessionPayload } from '../../src/lib/app/token.ts'

test('fresh token is kept', () => {
  assert.equal(needsFreshToken(1000, 900), false)
})

test('token within 60s needs refresh', () => {
  assert.equal(needsFreshToken(1000, 940), true)
})

test('missing expiry needs refresh', () => {
  assert.equal(needsFreshToken(null, 0), true)
})

test('payload strips refresh_token', () => {
  assert.deepEqual(
    parseSessionPayload({ access_token: 'a', expires_at: 1, refresh_token: 'r', user: { id: 'u' } }),
    { access_token: 'a', expires_at: 1, user: { id: 'u' } },
  )
})

test('malformed payload is rejected', () => {
  assert.equal(parseSessionPayload({ access_token: 1 }), null)
})
