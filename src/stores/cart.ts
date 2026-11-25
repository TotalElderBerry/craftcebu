import type { CatalogProduct } from '@/lib/catalog'
import { defineStore } from 'pinia'
import { computed, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import { inApp, postToNative } from '@/lib/app/bridge'
import { addToCart, fetchCartLines, removeCartItems, setCartQty, toCartLine } from '@/lib/cart'
import { useAuthStore } from '@/stores/auth'

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

const loadFailed = () => {
  toast.error('Could not load your cart.')
}

function readSaved(): CartLine[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    return raw ? JSON.parse(raw) : []
  }
  catch {
    return []
  }
}

function errorMessage(e: unknown) {
  const message = (e as { message?: string } | null)?.message ?? ''
  if (message.includes('sold_out')) return 'This piece is sold out.'
  if (message.includes('not_available')) return 'This piece is no longer available.'
  return 'Could not update your cart. Please try again.'
}

// Signed-in shoppers keep their cart in Supabase, shared with the phone app.
// Guests on the website keep it in this browser until they sign in, when it
// is merged into their account. Inside the app there is no guest cart.
export const useCartStore = defineStore('cart', () => {
  const auth = useAuthStore()
  const local = ref<CartLine[]>(readSaved())
  const remote = ref<CartLine[]>([])
  const signedIn = computed(() => Boolean(auth.user))

  watch(local, (value) => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(value))
    }
    catch {
      // Private windows can block storage; the cart still works for this visit.
    }
  }, { deep: true })

  const lines = computed<CartLine[]>(() => signedIn.value ? remote.value : inApp ? [] : local.value)

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

  // Tells the phone app to refresh its cart badge.
  function changed() {
    if (inApp) postToNative({ type: 'cartChanged' })
  }

  // Runs a database write after an optimistic change, putting the old lines
  // back if it fails.
  async function saveRemote(next: CartLine[], write: () => Promise<void>) {
    const before = remote.value
    remote.value = next
    try {
      await write()
      changed()
    }
    catch (e) {
      remote.value = before
      toast.error(errorMessage(e))
    }
  }

  // Resolves true when the pieces were added. In the app a guest is sent to
  // the app's sign-in instead.
  async function add(product: CatalogProduct, qty = 1): Promise<boolean> {
    if (!signedIn.value) {
      if (inApp) {
        postToNative({ type: 'login', returnTo: window.location.pathname + window.location.search })
        return false
      }
      const existing = local.value.find(l => l.productId === product.id)
      if (existing) existing.qty = Math.min(existing.qty + qty, product.stock)
      else local.value.push(toCartLine(product, Math.min(qty, product.stock)))
      return true
    }
    try {
      const line = toCartLine(product, await addToCart(product.id, qty))
      const index = remote.value.findIndex(l => l.productId === product.id)
      remote.value = index === -1 ? [...remote.value, line] : remote.value.map((l, i) => i === index ? line : l)
      changed()
      return true
    }
    catch (e) {
      toast.error(errorMessage(e))
      return false
    }
  }

  async function setQty(productId: string, qty: number) {
    if (!signedIn.value) {
      const line = local.value.find(l => l.productId === productId)
      if (line) line.qty = Math.max(1, Math.min(qty, line.stock))
      return
    }
    const line = remote.value.find(l => l.productId === productId)
    if (!line) return
    const next = Math.max(1, Math.min(qty, line.stock))
    await saveRemote(remote.value.map(l => l.productId === productId ? { ...l, qty: next } : l), () => setCartQty(productId, next))
  }

  async function removeMany(productIds: string[]) {
    if (!signedIn.value) {
      local.value = local.value.filter(l => !productIds.includes(l.productId))
      return
    }
    await saveRemote(remote.value.filter(l => !productIds.includes(l.productId)), () => removeCartItems(productIds))
  }

  const remove = (productId: string) => removeMany([productId])

  // Apply fresh product data; drops pieces that are gone or sold out.
  function refresh(fresh: CatalogProduct[]) {
    const dropped: { id: string, name: string }[] = []
    const clamped: CartLine[] = []
    const next = lines.value.flatMap((line) => {
      const p = fresh.find(f => f.id === line.productId)
      if (!p || p.stock === 0) {
        dropped.push({ id: line.productId, name: line.name })
        return []
      }
      const updated = toCartLine(p, Math.min(line.qty, p.stock))
      updated.image ??= line.image
      if (updated.qty !== line.qty) clamped.push(updated)
      return [updated]
    })
    if (signedIn.value) {
      remote.value = next
      if (dropped.length || clamped.length) {
        const writes = [removeCartItems(dropped.map(d => d.id)), ...clamped.map(l => setCartQty(l.productId, l.qty))]
        Promise.all(writes).then(changed, () => toast.error(errorMessage(null)))
      }
    }
    else {
      local.value = next
    }
    return dropped.map(d => d.name)
  }

  let loading: Promise<void> = Promise.resolve()

  async function load() {
    const { lines: fresh, unavailable } = await fetchCartLines()
    remote.value = fresh
    if (unavailable.length) {
      await removeCartItems(unavailable)
      changed()
    }
  }

  function reload() {
    if (!signedIn.value) return Promise.resolve()
    loading = load().catch(loadFailed)
    return loading
  }

  // A guest cart saved in this browser joins the account on sign-in.
  async function mergeThenLoad() {
    const saved = local.value
    if (saved.length) {
      await Promise.allSettled(saved.map(l => addToCart(l.productId, l.qty)))
      local.value = []
      changed()
    }
    await load()
  }

  // Sync, so loading starts the moment auth knows the user and whenLoaded()
  // can wait on it.
  watch(() => auth.user?.id, (id) => {
    remote.value = []
    if (id) loading = mergeThenLoad().catch(loadFailed)
  }, { immediate: true, flush: 'sync' })

  // Resolves once the signed-in cart (if any) has loaded.
  async function whenLoaded() {
    await auth.init()
    await loading
  }

  return { lines, count, shops, subtotal, add, setQty, remove, removeMany, refresh, reload, whenLoaded }
})
