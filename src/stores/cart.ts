import type { CatalogProduct } from '@/lib/catalog'
import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import { coverImage } from '@/lib/catalog'

// A snapshot for showing the cart quickly; the cart page refreshes prices and
// stock from the database, and place_order checks them again.
export interface CartLine {
  productId: string
  qty: number
  name: string
  slug: string
  price: number
  stock: number
  image: string | null
  artisan: { id: string, shopName: string, slug: string }
}

const STORAGE_KEY = 'craftcebu-cart'

function readSaved(): CartLine[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  }
  catch {
    return []
  }
}

export const useCartStore = defineStore('cart', () => {
  const lines = ref<CartLine[]>(readSaved())

  watch(lines, (value) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
    }
    catch {
      // Private windows can block storage; the cart still works for this visit.
    }
  }, { deep: true })

  const count = computed(() => lines.value.reduce((n, l) => n + l.qty, 0))

  // Lines grouped by shop, in the order shops were first added.
  const shops = computed(() => {
    const groups = new Map<string, { artisan: CartLine['artisan'], lines: CartLine[], subtotal: number }>()
    for (const line of lines.value) {
      const group = groups.get(line.artisan.id) ?? { artisan: line.artisan, lines: [], subtotal: 0 }
      group.lines.push(line)
      group.subtotal += line.price * line.qty
      groups.set(line.artisan.id, group)
    }
    return [...groups.values()]
  })

  const subtotal = computed(() => lines.value.reduce((s, l) => s + l.price * l.qty, 0))

  function add(product: CatalogProduct, qty = 1) {
    const existing = lines.value.find(l => l.productId === product.id)
    if (existing) {
      existing.qty = Math.min(existing.qty + qty, product.stock)
      return
    }
    lines.value.push({
      productId: product.id,
      qty: Math.min(qty, product.stock),
      name: product.name,
      slug: product.slug,
      price: product.price,
      stock: product.stock,
      image: coverImage(product),
      artisan: { id: product.artisan_id, shopName: product.artisan.shop_name, slug: product.artisan.slug },
    })
  }

  function setQty(productId: string, qty: number) {
    const line = lines.value.find(l => l.productId === productId)
    if (line) line.qty = Math.max(1, Math.min(qty, line.stock))
  }

  function remove(productId: string) {
    lines.value = lines.value.filter(l => l.productId !== productId)
  }

  function removeMany(productIds: string[]) {
    lines.value = lines.value.filter(l => !productIds.includes(l.productId))
  }

  // Apply fresh product data; drops pieces that are gone or sold out.
  function refresh(fresh: CatalogProduct[]) {
    const dropped: string[] = []
    lines.value = lines.value.flatMap((line) => {
      const p = fresh.find(f => f.id === line.productId)
      if (!p || p.stock === 0) {
        dropped.push(line.name)
        return []
      }
      return [{ ...line, name: p.name, price: p.price, stock: p.stock, qty: Math.min(line.qty, p.stock), image: coverImage(p) ?? line.image }]
    })
    return dropped
  }

  return { lines, count, shops, subtotal, add, setQty, remove, removeMany, refresh }
})
