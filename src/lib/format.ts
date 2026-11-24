const pesoFormat = new Intl.NumberFormat('en-PH', { style: 'currency', currency: 'PHP', maximumFractionDigits: 0 })

export const peso = (value: number) => pesoFormat.format(value)

export function yearsInCraft(craftSince: number | null) {
  if (!craftSince) return null
  return Math.max(1, new Date().getFullYear() - craftSince)
}
