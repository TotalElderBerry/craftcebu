<script setup lang="ts">
import type { CentreGroup } from '@/components/CentreShell.vue'
import { BoxIcon, ReceiptIcon, StoreIcon, WalletIcon } from '@lucide/vue'
import { computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import CentreShell from '@/components/CentreShell.vue'
import { useSellerStore } from '@/stores/seller'

const seller = useSellerStore()
const router = useRouter()

// Only a verified shop gets a Seller Centre; everyone else sees their application.
onMounted(async () => {
  const shop = await seller.load()
  if (shop?.status !== 'verified') router.replace({ name: 'sell' })
})

const groups: CentreGroup[] = [
  { title: 'Product', icon: BoxIcon, items: [{ label: 'My Products', to: '/seller/products' }, { label: 'Add New Product', to: '/seller/products/new' }] },
  { title: 'Order', icon: ReceiptIcon, items: [{ label: 'My Orders', to: '/seller/orders' }, { label: 'Cancellations', to: '/seller/orders?tab=cancelled' }] },
  { title: 'Shop', icon: StoreIcon, items: [{ label: 'Shop Profile', to: '/seller/shop' }] },
  { title: 'Finance', icon: WalletIcon, items: [{ label: 'My Income', to: '/seller/income' }] },
]

const storeLink = computed(() => seller.shop ? { label: 'View my shop', to: `/artisans/${seller.shop.slug}` } : undefined)
</script>

<template>
  <CentreShell name="Seller Centre" home="/seller" :groups="groups" :store-link="storeLink" />
</template>
