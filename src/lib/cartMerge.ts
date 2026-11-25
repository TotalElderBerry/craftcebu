// Pure cart helpers with no imports, so `node --test` can load them.

const REFUSALS = ['sold_out', 'not_available']

// Adds a guest's browser cart to their account. Returns the lines that could
// not be added for now (a network blip), so they stay for the next sign-in;
// lines the database refused (sold out, gone) are dropped like merged ones.
export async function mergeGuestLines<T extends { productId: string, qty: number }>(
  lines: T[],
  add: (productId: string, qty: number) => Promise<unknown>,
): Promise<T[]> {
  const results = await Promise.allSettled(lines.map(l => add(l.productId, l.qty)))
  return lines.filter((_, i) => {
    const r = results[i]
    if (r.status === 'fulfilled') return false
    const message = String((r.reason as { message?: string } | null)?.message ?? '')
    return !REFUSALS.some(code => message.includes(code))
  })
}

// The toast for pieces taken out of a cart: named ones (sold out) and ones
// whose product can no longer be read at all (hidden or removed by the shop).
export function removedNotice(names: string[], hiddenCount: number): string | null {
  const pieces = (n: number) => `${n} ${n === 1 ? 'piece' : 'pieces'}`
  if (!names.length && !hiddenCount) return null
  if (!names.length) return `Removed ${pieces(hiddenCount)} from your cart because they're no longer available.`
  const more = hiddenCount ? `, and ${hiddenCount} more ${hiddenCount === 1 ? 'piece' : 'pieces'}` : ''
  return `Removed from your cart because they're no longer available: ${names.join(', ')}${more}`
}
