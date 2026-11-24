<script setup lang="ts">
import type { PayoutBalance, PayoutRow } from '@/lib/admin'
import { computed, onMounted, ref } from 'vue'
import AdminCard from '@/components/admin/AdminCard.vue'
import { fetchPayoutBalances, fetchPayouts } from '@/lib/admin'
import { peso } from '@/lib/format'

// The same numbers the owner sees on Payouts, limited to this shop by the database.
const balance = ref<PayoutBalance | null>(null)
const history = ref<PayoutRow[]>([])
const loading = ref(true)

onMounted(async () => {
  try {
    const [b, h] = await Promise.all([fetchPayoutBalances(), fetchPayouts()])
    balance.value = b[0] ?? null
    history.value = h
  }
  finally {
    loading.value = false
  }
})

const net = computed(() => Number(balance.value?.net ?? 0))
</script>

<template>
  <div class="mx-auto grid max-w-5xl gap-4">
    <div class="grid gap-4 sm:grid-cols-3">
      <div class="rounded-lg border bg-card p-5 sm:col-span-1">
        <p class="text-sm text-muted-foreground">{{ net >= 0 ? 'CraftCebu owes you' : 'You owe CraftCebu' }}</p>
        <p class="mt-1 text-3xl font-semibold tabular-nums">{{ loading ? '–' : peso(Math.abs(net)) }}</p>
        <p class="text-xs text-muted-foreground">{{ balance?.delivered_orders ?? 0 }} delivered {{ balance?.delivered_orders === 1 ? 'order' : 'orders' }} not yet settled</p>
      </div>
      <div class="rounded-lg border bg-card p-5">
        <p class="text-sm text-muted-foreground">Online sales, after commission</p>
        <p class="mt-1 text-2xl font-semibold tabular-nums">{{ peso(balance?.online_owed ?? 0) }}</p>
      </div>
      <div class="rounded-lg border bg-card p-5">
        <p class="text-sm text-muted-foreground">Commission on COD orders</p>
        <p class="mt-1 text-2xl font-semibold tabular-nums">{{ peso(balance?.cod_commission ?? 0) }}</p>
      </div>
    </div>

    <AdminCard title="Payout history" subtitle="Settlements the CraftCebu owner has recorded with you.">
      <div class="overflow-x-auto">
        <table class="mt-4 w-full min-w-[520px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Period</th>
              <th class="px-5 py-3 font-medium">Amount</th>
              <th class="px-5 py-3 font-medium">Settled</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="!history.length"><td colspan="3" class="px-5 py-12 text-center text-muted-foreground">No payouts yet. They appear here once the owner settles your delivered orders.</td></tr>
            <tr v-for="p in history" :key="p.id">
              <td class="px-5 py-3">{{ p.period }}</td>
              <td class="px-5 py-3 tabular-nums">{{ Number(p.amount) >= 0 ? `Received ${peso(p.amount)}` : `Paid ${peso(-p.amount)} commission` }}</td>
              <td class="px-5 py-3 text-muted-foreground">{{ p.paid_at ? new Date(p.paid_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <p class="border-t px-5 py-3 text-xs text-muted-foreground">Online payments reach CraftCebu first, so you receive your subtotal plus shipping, minus commission. For cash on delivery you keep the cash and owe the commission.</p>
    </AdminCard>
  </div>
</template>
