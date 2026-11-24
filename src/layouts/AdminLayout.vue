<script setup lang="ts">
import type { CentreGroup } from '@/components/CentreShell.vue'
import { BadgeCheckIcon, BoxIcon, MegaphoneIcon, ReceiptIcon, SettingsIcon, WalletIcon } from '@lucide/vue'
import CentreShell from '@/components/CentreShell.vue'

// Grouped like Shopee Seller Centre.
const groups: CentreGroup[] = [
  { title: 'Artisans', icon: BadgeCheckIcon, items: [{ label: 'Applications', to: '/admin/applications' }, { label: 'All Artisans', to: '/admin/artisans' }] },
  { title: 'Order', icon: ReceiptIcon, items: [{ label: 'All Orders', to: '/admin/orders' }, { label: 'Cancellations', to: '/admin/orders?status=cancelled' }] },
  { title: 'Product', icon: BoxIcon, items: [{ label: 'All Products', to: '/admin/products' }, { label: 'Hidden Products', to: '/admin/products?tab=hidden' }] },
  { title: 'Marketing Centre', icon: MegaphoneIcon, items: [{ label: 'Featured Artisan', to: '/admin/homepage' }, { label: 'Homepage Banners', to: '/admin/homepage?tab=banners' }] },
  { title: 'Finance', icon: WalletIcon, items: [{ label: 'Payouts', to: '/admin/payouts' }, { label: 'Commission', to: '/admin/settings' }] },
  { title: 'Platform', icon: SettingsIcon, items: [{ label: 'Users', to: '/admin/users' }, { label: 'Reviews', to: '/admin/reviews' }, { label: 'Catalog Setup', to: '/admin/catalog' }, { label: 'Activity Log', to: '/admin/activity' }] },
]
</script>

<template>
  <CentreShell name="Admin Centre" home="/admin" :groups="groups" />
</template>
