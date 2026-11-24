<script setup lang="ts">
import type { ActivityRow } from '@/lib/admin'
import { onMounted, ref } from 'vue'
import AdminCard from '@/components/admin/AdminCard.vue'
import { Button } from '@/components/ui/button'
import { actionLabels, fetchActivity } from '@/lib/admin'
import { peso } from '@/lib/format'

const rows = ref<ActivityRow[]>([])
const total = ref(0)
const page = ref(0)
const loading = ref(true)

async function load(more = false) {
  loading.value = true
  try {
    const res = await fetchActivity(page.value)
    rows.value = more ? [...rows.value, ...res.rows] : res.rows
    total.value = res.total
  }
  finally {
    loading.value = false
  }
}
onMounted(() => load())

function detail(r: ActivityRow) {
  const d = r.details ?? {}
  if (r.action === 'settle_payout') return `${peso(Number(d.amount))} · ${d.orders} orders`
  if (r.action === 'update_setting') return `${r.target_id}: ${JSON.stringify(d.from)} → ${JSON.stringify(d.to)}`
  if (r.action === 'reject_artisan' && d.reason) return `“${d.reason}”`
  return (d.shop ?? d.name ?? '') as string
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <AdminCard title="Activity Log" :subtitle="`${total} owner actions, newest first`">
      <div class="overflow-x-auto">
        <table class="mt-4 w-full min-w-[620px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">When</th>
              <th class="px-5 py-3 font-medium">Who</th>
              <th class="px-5 py-3 font-medium">What</th>
              <th class="px-5 py-3 font-medium">Details</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="!rows.length && !loading"><td colspan="4" class="px-5 py-12 text-center text-muted-foreground">No owner actions yet.</td></tr>
            <tr v-for="r in rows" :key="r.id">
              <td class="px-5 py-3 whitespace-nowrap text-muted-foreground">{{ new Date(r.created_at).toLocaleString('en-PH', { dateStyle: 'medium', timeStyle: 'short' }) }}</td>
              <td class="px-5 py-3">{{ r.actor?.full_name || 'Owner' }}</td>
              <td class="px-5 py-3 font-medium">{{ actionLabels[r.action] ?? r.action }}</td>
              <td class="px-5 py-3 text-muted-foreground">{{ detail(r) }}</td>
            </tr>
          </tbody>
        </table>
      </div>
      <div v-if="rows.length < total" class="flex justify-center border-t p-4">
        <Button variant="outline" size="sm" :disabled="loading" @click="page++; load(true)">Show more</Button>
      </div>
    </AdminCard>
  </div>
</template>
