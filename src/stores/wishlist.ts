import { defineStore } from 'pinia'
import { ref, watch } from 'vue'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

// The signed-in buyer's saved product ids, kept in the wishlists table.
export const useWishlistStore = defineStore('wishlist', () => {
  const auth = useAuthStore()
  const ids = ref(new Set<string>())

  async function load(userId: string | undefined) {
    if (!userId) {
      ids.value = new Set()
      return
    }
    const { data } = await supabase.from('wishlists').select('product_id').eq('profile_id', userId)
    ids.value = new Set((data ?? []).map(r => r.product_id))
  }
  watch(() => auth.user?.id, load, { immediate: true })

  const has = (productId: string) => ids.value.has(productId)

  // Returns the new saved state. Callers send signed-out users to log in first.
  async function toggle(productId: string) {
    const userId = auth.user!.id
    const next = new Set(ids.value)
    if (next.has(productId)) {
      next.delete(productId)
      ids.value = next
      const { error } = await supabase.from('wishlists').delete().eq('profile_id', userId).eq('product_id', productId)
      if (error) {
        ids.value = new Set([...ids.value, productId])
        throw error
      }
      return false
    }
    next.add(productId)
    ids.value = next
    const { error } = await supabase.from('wishlists').insert({ profile_id: userId, product_id: productId })
    if (error) {
      const rollback = new Set(ids.value)
      rollback.delete(productId)
      ids.value = rollback
      throw error
    }
    return true
  }

  return { ids, has, toggle, load }
})
