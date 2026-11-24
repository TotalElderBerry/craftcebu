<script setup lang="ts">
import type { Application } from '@/lib/seller'
import type { ArtisanStatus } from '@/types/database'
import { CheckIcon, ExpandIcon, MapPinIcon, XIcon } from '@lucide/vue'
import { computed, onMounted, ref, watch } from 'vue'
import { toast } from 'vue-sonner'
import { Button } from '@/components/ui/button'
import { Label } from '@/components/ui/label'
import { Sheet, SheetContent, SheetDescription, SheetHeader, SheetTitle } from '@/components/ui/sheet'
import { Textarea } from '@/components/ui/textarea'
import { yearsInCraft } from '@/lib/format'
import { fetchApplications, reviewApplication } from '@/lib/seller'
import { supabase } from '@/lib/supabase'
import { cn } from '@/lib/utils'

const tabs: { key: ArtisanStatus, label: string }[] = [
  { key: 'pending', label: 'To review' },
  { key: 'verified', label: 'Approved' },
  { key: 'rejected', label: 'Rejected' },
]
const tab = ref<ArtisanStatus>('pending')
const counts = ref<Record<string, number>>({})
const rows = ref<Application[]>([])
const loading = ref(true)

const selected = ref<Application | null>(null)
const open = computed({
  get: () => !!selected.value,
  set: (v) => { if (!v) selected.value = null },
})
const rejecting = ref(false)
const enlarged = ref<string | null>(null)
const reason = ref('')
const busy = ref(false)

async function loadCounts() {
  const results = await Promise.all(tabs.map(t =>
    supabase.from('artisans').select('*', { count: 'exact', head: true }).eq('status', t.key),
  ))
  counts.value = Object.fromEntries(tabs.map((t, i) => [t.key, results[i]!.count ?? 0]))
}

async function load() {
  loading.value = true
  try {
    rows.value = await fetchApplications(tab.value)
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not load applications')
  }
  finally {
    loading.value = false
  }
}

onMounted(() => Promise.all([load(), loadCounts()]))
watch(tab, load)

function review(app: Application) {
  selected.value = app
  rejecting.value = false
  reason.value = ''
}

async function decide(approve: boolean) {
  if (!selected.value) return
  if (!approve && reason.value.trim().length < 10) {
    toast.error('Tell the applicant what to change (at least 10 characters).')
    return
  }
  busy.value = true
  try {
    await reviewApplication(selected.value.id, approve, approve ? undefined : reason.value.trim())
    toast.success(approve ? `${selected.value.shop_name} is now verified.` : `Sent back to ${selected.value.shop_name} with your notes.`)
    selected.value = null
    await Promise.all([load(), loadCounts()])
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save the decision')
  }
  finally {
    busy.value = false
  }
}

const date = (iso: string) => new Date(iso).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' })
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <section class="rounded-lg border bg-card">
      <div class="border-b px-5 pt-5">
        <h1 class="text-lg font-semibold">Artisan Applications</h1>
        <p class="text-sm text-muted-foreground">Check each maker's story and work before their shop goes live.</p>
        <div class="mt-4 flex gap-6 text-sm" role="tablist">
          <button
            v-for="t in tabs"
            :key="t.key"
            role="tab"
            :aria-selected="tab === t.key"
            :class="cn('-mb-px border-b-2 pb-3 font-medium transition-colors', tab === t.key ? 'border-primary text-primary' : 'border-transparent text-muted-foreground hover:text-foreground')"
            @click="tab = t.key"
          >
            {{ t.label }} <span class="ml-1 rounded-full bg-secondary px-2 py-0.5 text-xs tabular-nums">{{ counts[t.key] ?? '–' }}</span>
          </button>
        </div>
      </div>

      <!-- Phones: one card per application -->
      <ul class="divide-y md:hidden">
        <li v-if="loading" class="px-5 py-10 text-center text-sm text-muted-foreground">Loading…</li>
        <li v-else-if="!rows.length" class="px-5 py-12 text-center text-sm text-muted-foreground">{{ tab === 'pending' ? 'No applications waiting. Nice work!' : 'Nothing here yet.' }}</li>
        <li v-for="a in rows" v-else :key="a.id" class="flex items-center gap-3 px-4 py-4">
          <img v-if="a.photo_url" :src="a.photo_url" alt="" class="size-12 shrink-0 rounded-full object-cover">
          <div v-else class="grid size-12 shrink-0 place-items-center rounded-full bg-primary font-display text-primary-foreground">{{ a.shop_name[0] }}</div>
          <div class="min-w-0 flex-1 text-sm">
            <p class="truncate font-medium">{{ a.shop_name }}</p>
            <p class="truncate text-xs text-muted-foreground">{{ a.owner?.full_name || '—' }} · {{ a.town?.name ?? '—' }} · {{ date(a.verified_at ?? a.created_at) }}</p>
          </div>
          <Button size="sm" :variant="tab === 'pending' ? 'default' : 'outline'" class="shrink-0 rounded-full" @click="review(a)">{{ tab === 'pending' ? 'Review' : 'View' }}</Button>
        </li>
      </ul>

      <div class="hidden overflow-x-auto md:block">
        <table class="w-full min-w-[720px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Shop</th>
              <th class="px-5 py-3 font-medium">Applicant</th>
              <th class="px-5 py-3 font-medium">Town</th>
              <th class="px-5 py-3 font-medium">{{ tab === 'verified' ? 'Approved' : 'Submitted' }}</th>
              <th class="px-5 py-3 text-right font-medium">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="5" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!rows.length">
              <td colspan="5" class="px-5 py-12 text-center text-muted-foreground">
                {{ tab === 'pending' ? 'No applications waiting. Nice work!' : 'Nothing here yet.' }}
              </td>
            </tr>
            <tr v-for="a in rows" v-else :key="a.id" class="hover:bg-secondary/40">
              <td class="px-5 py-3">
                <div class="flex items-center gap-3">
                  <img v-if="a.photo_url" :src="a.photo_url" alt="" class="size-10 rounded-full object-cover">
                  <div v-else class="grid size-10 place-items-center rounded-full bg-primary font-display text-primary-foreground">{{ a.shop_name[0] }}</div>
                  <span class="font-medium">{{ a.shop_name }}</span>
                </div>
              </td>
              <td class="px-5 py-3 text-muted-foreground">{{ a.owner?.full_name || '—' }}</td>
              <td class="px-5 py-3">{{ a.town?.name ?? '—' }}</td>
              <td class="px-5 py-3 text-muted-foreground">{{ date(a.verified_at ?? a.created_at) }}</td>
              <td class="px-5 py-3 text-right">
                <Button size="sm" :variant="tab === 'pending' ? 'default' : 'outline'" class="rounded-full" @click="review(a)">
                  {{ tab === 'pending' ? 'Review' : 'View' }}
                </Button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>

    <Sheet v-model:open="open">
      <SheetContent class="w-full overflow-y-auto sm:max-w-lg">
        <template v-if="selected">
          <SheetHeader>
            <SheetTitle class="font-display text-2xl font-medium">{{ selected.shop_name }}</SheetTitle>
            <SheetDescription class="flex flex-wrap gap-x-4 gap-y-1">
              <span>by {{ selected.owner?.full_name || 'unnamed applicant' }}</span>
              <span v-if="selected.town" class="flex items-center gap-1"><MapPinIcon class="size-3.5" />{{ selected.town.name }}</span>
              <span v-if="selected.craft_since">Since {{ selected.craft_since }} ({{ yearsInCraft(selected.craft_since) }} yrs)</span>
            </SheetDescription>
          </SheetHeader>

          <div class="grid gap-6 px-4 pb-6">
            <img v-if="selected.photo_url" :src="selected.photo_url" alt="Shop photo" class="h-56 w-40 rounded-t-[999px] rounded-b-lg object-cover">

            <section>
              <h3 class="caps text-muted-foreground">Story</h3>
              <p class="mt-2 leading-relaxed whitespace-pre-line">{{ selected.story }}</p>
            </section>

            <section>
              <h3 class="caps text-muted-foreground">Sample work ({{ selected.sample_photos.length }})</h3>
              <div v-if="selected.sample_photos.length" class="mt-2 grid grid-cols-3 gap-2">
                <button v-for="url in selected.sample_photos" :key="url" type="button" class="group relative block overflow-hidden rounded-md" aria-label="Enlarge photo" @click="enlarged = url">
                  <img :src="url" alt="Sample of the applicant's work" class="aspect-square w-full object-cover transition-transform group-hover:scale-105">
                  <ExpandIcon class="absolute top-1.5 right-1.5 size-3.5 text-white drop-shadow [@media(hover:hover)]:opacity-0 [@media(hover:hover)]:group-hover:opacity-100" />
                </button>
              </div>
              <p v-else class="mt-2 text-sm text-muted-foreground">No sample photos.</p>
            </section>

            <p v-if="selected.status === 'rejected' && selected.reject_reason" class="rounded-lg bg-destructive/5 p-3 text-sm">
              <span class="font-semibold">Rejected:</span> {{ selected.reject_reason }}
            </p>

            <div v-if="selected.status === 'pending'" class="grid gap-3 border-t pt-6">
              <template v-if="rejecting">
                <Label for="reason">What should they change?</Label>
                <Textarea id="reason" v-model="reason" rows="3" placeholder="e.g. Please add clearer photos of finished pieces." />
                <div class="flex gap-2">
                  <Button variant="outline" class="flex-1" :disabled="busy" @click="rejecting = false">Cancel</Button>
                  <Button class="flex-1 bg-destructive hover:bg-destructive/90" :disabled="busy" @click="decide(false)">Send back</Button>
                </div>
              </template>
              <div v-else class="flex gap-2">
                <Button variant="outline" class="flex-1" :disabled="busy" @click="rejecting = true"><XIcon /> Reject</Button>
                <Button class="flex-1" :disabled="busy" @click="decide(true)"><CheckIcon /> Approve</Button>
              </div>
              <p class="text-xs text-muted-foreground">Approving adds the Verified badge and opens their Seller Centre. Every decision goes in the activity log.</p>
            </div>
          </div>
        </template>
      </SheetContent>
    </Sheet>

    <!-- Full-screen photo viewer for sample work -->
    <div v-if="enlarged" class="pt-safe pb-safe fixed inset-0 z-[60] grid place-items-center bg-black/90 p-4" role="dialog" aria-label="Sample photo" @click="enlarged = null">
      <img :src="enlarged" alt="Sample of the applicant's work" class="max-h-full max-w-full rounded-lg object-contain">
      <button class="absolute top-[calc(env(safe-area-inset-top)+0.75rem)] right-3 grid size-11 place-items-center rounded-full bg-white/15 text-white" aria-label="Close photo"><XIcon class="size-5" /></button>
    </div>
  </div>
</template>
