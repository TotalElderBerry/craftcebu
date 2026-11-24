import type { MyArtisan } from '@/lib/seller'
import { defineStore } from 'pinia'
import { ref } from 'vue'
import { fetchMyArtisan } from '@/lib/seller'
import { useAuthStore } from '@/stores/auth'

// The signed-in artisan's own shop, loaded once by the Seller Centre layout.
export const useSellerStore = defineStore('seller', () => {
  const shop = ref<MyArtisan | null>(null)

  async function load() {
    const auth = useAuthStore()
    shop.value = auth.user ? await fetchMyArtisan(auth.user.id) : null
    return shop.value
  }

  return { shop, load }
})
