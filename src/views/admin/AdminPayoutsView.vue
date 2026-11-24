<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { PayoutBalance, PayoutRow } from '@/lib/admin'
import { InfoIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import { Button } from '@/components/ui/button'
import { fetchPayoutBalances, fetchPayouts, settlePayout } from '@/lib/admin'
import { peso } from '@/lib/format'
import { cn } from '@/lib/utils'

const balances = ref<PayoutBalance[]>([])
const history = ref<PayoutRow[]>([])
const loading = ref(true)
const tab = ref<'owed' | 'history'>('owed')
const busy = ref<string | null>(null)

async function load() {
  loading.value = true
  try {
    ;[balances.value, history.value] = await Promise.all([fetchPayoutBalances(), fetchPayouts()])
  }
  finally {
    loading.value = false
  }
}
onMounted(load)

const totalOwed = computed(() => balances.value.reduce((s, b) => s + Math.max(0, Number(b.net)), 0))
const totalDue = computed(() => balances.value.reduce((s, b) => s + Math.max(0, -Number(b.net)), 0))

async function settle(b: PayoutBalance) {
  const net = Number(b.net)
  const text = net >= 0 ? `Record that you paid ${b.shop_name} ${peso(net)}?` : `Record that ${b.shop_name} paid you ${peso(-net)} in commission?`
  if (!await confirmAction({ title: text, body: `This settles ${b.delivered_orders} delivered ${b.delivered_orders === 1 ? 'order' : 'orders'}. CraftCebu only records it; no money moves.`, confirmLabel: 'Mark settled' })) return
  busy.value = b.artisan_id
  try {
    await settlePayout(b.artisan_id)
    toast.success('Payout recorded.')
    await load()
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not record the payout')
  }
  finally {
    busy.value = null
  }
}
</script>

<template>
  <div class="mx-auto grid max-w-7xl gap-4">
    <div class="grid gap-4 sm:grid-cols-2">
      <div class="rounded-lg border bg-card p-5">
        <p class="text-sm text-muted-foreground">You owe artisans</p>
        <p class="mt-1 text-3xl font-semibold tabular-nums">{{ peso(totalOwed) }}</p>
        <p class="text-xs text-muted-foreground">From online payments (Maya, demo) on delivered orders</p>
      </div>
      <div class="rounded-lg border bg-card p-5">
        <p class="text-sm text-muted-foreground">Artisans owe you</p>
        <p class="mt-1 text-3xl font-semibold tabular-nums">{{ peso(totalDue) }}</p>
        <p class="text-xs text-muted-foreground">Commission on cash-on-delivery orders they collected</p>
      </div>
    </div>

    <AdminCard title="Payouts" subtitle="Tracking only: settle a shop after you've paid them (or they've paid you) outside CraftCebu.">
      <template #tabs>
        <TabButton :active="tab === 'owed'" :count="balances.length" @select="tab = 'owed'">To settle</TabButton>
        <TabButton :active="tab === 'history'" :count="history.length" @select="tab = 'history'">History</TabButton>
      </template>

      <div v-if="tab === 'owed'" class="overflow-x-auto">
        <table class="w-full min-w-[720px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Shop</th>
              <th class="px-5 py-3 font-medium">Delivered orders</th>
              <th class="px-5 py-3 font-medium">Online, after commission</th>
              <th class="px-5 py-3 font-medium">COD commission due</th>
              <th class="px-5 py-3 font-medium">Net</th>
              <th class="px-5 py-3 text-right font-medium">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="6" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!balances.length"><td colspan="6" class="px-5 py-12 text-center text-muted-foreground">Everything is settled. Balances appear once orders are delivered.</td></tr>
            <tr v-for="b in balances" v-else :key="b.artisan_id" class="hover:bg-secondary/40">
              <td class="px-5 py-3 font-medium">{{ b.shop_name }}</td>
              <td class="px-5 py-3 tabular-nums">{{ b.delivered_orders }}</td>
              <td class="px-5 py-3 tabular-nums">{{ peso(b.online_owed) }}</td>
              <td class="px-5 py-3 tabular-nums">{{ peso(b.cod_commission) }}</td>
              <td :class="cn('px-5 py-3 font-semibold tabular-nums', Number(b.net) < 0 && 'text-primary')">
                {{ Number(b.net) >= 0 ? `Pay ${peso(b.net)}` : `Collect ${peso(-b.net)}` }}
              </td>
              <td class="px-5 py-3 text-right">
                <Button size="sm" class="rounded-full" :disabled="busy === b.artisan_id" @click="settle(b)">Mark settled</Button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div v-else class="overflow-x-auto">
        <table class="w-full min-w-[620px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Shop</th>
              <th class="px-5 py-3 font-medium">Period</th>
              <th class="px-5 py-3 font-medium">Amount</th>
              <th class="px-5 py-3 font-medium">Settled</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="!history.length"><td colspan="4" class="px-5 py-12 text-center text-muted-foreground">No payouts recorded yet.</td></tr>
            <tr v-for="p in history" :key="p.id">
              <td class="px-5 py-3 font-medium">{{ p.artisan?.shop_name }}</td>
              <td class="px-5 py-3 text-muted-foreground">{{ p.period }}</td>
              <td class="px-5 py-3 tabular-nums">{{ Number(p.amount) >= 0 ? `Paid ${peso(p.amount)}` : `Received ${peso(-p.amount)}` }}</td>
              <td class="px-5 py-3 text-muted-foreground">{{ p.paid_at ? new Date(p.paid_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) : '—' }}</td>
            </tr>
          </tbody>
        </table>
      </div>

      <p class="flex gap-2 border-t px-5 py-3 text-xs text-muted-foreground">
        <InfoIcon class="size-4 shrink-0" />
        Online payments reach CraftCebu, so you owe the shop its subtotal plus shipping, minus commission. With cash on delivery the shop already has the cash, so it owes you the commission.
      </p>
    </AdminCard>
  </div>
</template>
