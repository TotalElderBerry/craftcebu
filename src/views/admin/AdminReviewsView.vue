<script setup lang="ts">
import type { AdminReview } from '@/lib/admin'
import { StarIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import { Button } from '@/components/ui/button'
import { fetchAllReviews, setReviewHidden } from '@/lib/admin'
import { cn } from '@/lib/utils'

const rows = ref<AdminReview[]>([])
const loading = ref(true)
const tab = ref<'visible' | 'hidden'>('visible')
const busy = ref<string | null>(null)

onMounted(async () => {
  try {
    rows.value = await fetchAllReviews()
  }
  finally {
    loading.value = false
  }
})

const visible = computed(() => rows.value.filter(r => (tab.value === 'hidden') === r.is_hidden))

async function toggle(r: AdminReview) {
  busy.value = r.id
  try {
    await setReviewHidden(r.id, !r.is_hidden)
    r.is_hidden = !r.is_hidden
    toast.success(r.is_hidden ? 'Review hidden from the product page.' : 'Review visible again.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update the review')
  }
  finally {
    busy.value = null
  }
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <AdminCard title="Reviews" subtitle="Hide reviews that are abusive, off-topic or spam. Hidden reviews stay visible to their author.">
      <template #tabs>
        <TabButton :active="tab === 'visible'" :count="rows.filter(r => !r.is_hidden).length" @select="tab = 'visible'">Visible</TabButton>
        <TabButton :active="tab === 'hidden'" :count="rows.filter(r => r.is_hidden).length" @select="tab = 'hidden'">Hidden</TabButton>
      </template>
      <div class="divide-y">
        <p v-if="loading" class="px-5 py-10 text-center text-sm text-muted-foreground">Loading…</p>
        <p v-else-if="!visible.length" class="px-5 py-12 text-center text-sm text-muted-foreground">No reviews here yet. Buyers can review a piece once it's delivered.</p>
        <article v-for="r in visible" v-else :key="r.id" class="flex flex-wrap items-start justify-between gap-4 px-5 py-4">
          <div class="min-w-0 flex-1">
            <div class="flex items-center gap-2">
              <span class="flex" :aria-label="`${r.rating} out of 5 stars`">
                <StarIcon v-for="n in 5" :key="n" :class="cn('size-4', n <= r.rating ? 'fill-mango text-mango' : 'text-border')" />
              </span>
              <RouterLink v-if="r.product" :to="`/product/${r.product.slug}`" class="text-sm font-medium hover:text-primary">{{ r.product.name }}</RouterLink>
            </div>
            <p class="mt-2 text-sm">{{ r.comment || 'No comment.' }}</p>
            <p class="mt-1 text-xs text-muted-foreground">{{ r.buyer?.full_name || 'Buyer' }} · {{ new Date(r.created_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) }}</p>
          </div>
          <Button size="sm" variant="outline" class="rounded-full" :disabled="busy === r.id" @click="toggle(r)">{{ r.is_hidden ? 'Unhide' : 'Hide' }}</Button>
        </article>
      </div>
    </AdminCard>
  </div>
</template>
