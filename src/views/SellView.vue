<script setup lang="ts">
import type { ApplicationInput, MyArtisan } from '@/lib/seller'
import { BadgeCheckIcon, ClockIcon, StoreIcon, XCircleIcon } from '@lucide/vue'
import { onMounted, ref } from 'vue'
import { toast } from 'vue-sonner'
import ShopProfileForm from '@/components/seller/ShopProfileForm.vue'
import StampBadge from '@/components/StampBadge.vue'
import { Button } from '@/components/ui/button'
import { fetchMyArtisan, resubmitApplication, submitApplication, updateShop } from '@/lib/seller'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const artisan = ref<MyArtisan | null>(null)
const loading = ref(true)
const saving = ref(false)
const editing = ref(false)

async function load() {
  artisan.value = await fetchMyArtisan(auth.user!.id)
  // Approval changes the role in the database; refresh the cached profile.
  if (artisan.value?.status === 'verified' && auth.role === 'buyer') await auth.loadProfile()
}

onMounted(async () => {
  try {
    await load()
  }
  finally {
    loading.value = false
  }
})

async function apply(input: ApplicationInput) {
  saving.value = true
  try {
    artisan.value = await submitApplication(auth.user!.id, input)
    toast.success('Application sent. Salamat! We\'ll review it soon.')
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not send your application')
  }
  finally {
    saving.value = false
  }
}

async function resubmit(input: ApplicationInput) {
  if (!artisan.value) return
  saving.value = true
  try {
    await updateShop(artisan.value.id, input)
    await resubmitApplication()
    await load()
    editing.value = false
    toast.success('Application resubmitted for review.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not resubmit')
  }
  finally {
    saving.value = false
  }
}

const perks = [
  { title: 'Your story first', body: 'Your shop page opens with you, your town and your craft.' },
  { title: 'Verified badge', body: 'Buyers see the Verified Cebuano Artisan stamp on your shop and products.' },
  { title: 'You ship, you earn', body: 'Buyers pay through CraftCebu; you pack and ship your own orders.' },
]
</script>

<template>
  <div class="mx-auto max-w-6xl px-4 py-12">
    <div v-if="loading" class="h-80 animate-pulse rounded-2xl bg-muted" />

    <!-- No application yet -->
    <div v-else-if="!artisan" class="grid gap-12 lg:grid-cols-[1fr_1.4fr]">
      <div>
        <p class="caps text-primary">Para sa mga artisan</p>
        <h1 class="mt-3 font-display text-4xl font-medium sm:text-5xl">Open your CraftCebu shop</h1>
        <p class="mt-4 text-muted-foreground">Tell us about yourself and your craft. We review every application so buyers know each shop is run by a real Cebuano maker.</p>
        <ul class="mt-8 grid gap-5">
          <li v-for="p in perks" :key="p.title" class="flex gap-3">
            <BadgeCheckIcon class="mt-0.5 size-5 shrink-0 text-primary" />
            <span><span class="font-semibold">{{ p.title }}.</span> <span class="text-muted-foreground">{{ p.body }}</span></span>
          </li>
        </ul>
        <StampBadge class="mt-10 hidden lg:grid" />
      </div>
      <div class="rounded-2xl border bg-card p-6 sm:p-8">
        <h2 class="font-display text-2xl font-medium">Your application</h2>
        <p class="mt-1 mb-6 text-sm text-muted-foreground">Usually reviewed within a few days.</p>
        <ShopProfileForm submit-label="Send application" with-samples :saving="saving" @submit="apply" />
      </div>
    </div>

    <!-- Under review -->
    <div v-else-if="artisan.status === 'pending'" class="mx-auto max-w-xl text-center">
      <div class="mx-auto grid size-16 place-items-center rounded-full bg-mango/30"><ClockIcon class="size-8 text-primary" /></div>
      <h1 class="mt-6 font-display text-4xl font-medium">We're reviewing your application</h1>
      <p class="mt-3 text-muted-foreground">Thanks for applying with <span class="font-medium text-foreground">{{ artisan.shop_name }}</span>. We'll check your story and photos, and your Seller Centre opens as soon as you're approved.</p>
      <Button as-child variant="outline" class="mt-8"><RouterLink to="/shop">Browse the crafts meanwhile</RouterLink></Button>
    </div>

    <!-- Rejected: show the reason and let them fix and resubmit -->
    <div v-else-if="artisan.status === 'rejected'" class="mx-auto max-w-2xl">
      <div class="flex gap-4 rounded-2xl border border-destructive/30 bg-destructive/5 p-6">
        <XCircleIcon class="size-6 shrink-0 text-destructive" />
        <div>
          <h1 class="font-display text-2xl font-medium">Your application needs changes</h1>
          <p v-if="artisan.reject_reason" class="mt-2 text-sm"><span class="font-semibold">From our review:</span> {{ artisan.reject_reason }}</p>
          <Button v-if="!editing" class="mt-4" @click="editing = true">Edit and resubmit</Button>
        </div>
      </div>
      <div v-if="editing" class="mt-8 rounded-2xl border bg-card p-6 sm:p-8">
        <ShopProfileForm :initial="artisan" submit-label="Resubmit application" with-samples :saving="saving" @submit="resubmit" />
      </div>
    </div>

    <!-- Approved -->
    <div v-else-if="artisan.status === 'verified'" class="mx-auto max-w-xl text-center">
      <StampBadge class="mx-auto" />
      <h1 class="mt-6 font-display text-4xl font-medium">You're a verified artisan</h1>
      <p class="mt-3 text-muted-foreground"><span class="font-medium text-foreground">{{ artisan.shop_name }}</span> is live. Add your products from the Seller Centre.</p>
      <Button as-child size="lg" class="mt-8"><RouterLink to="/seller"><StoreIcon /> Go to Seller Centre</RouterLink></Button>
    </div>

    <!-- Suspended -->
    <div v-else class="mx-auto max-w-xl text-center">
      <h1 class="font-display text-4xl font-medium">Your shop is paused</h1>
      <p class="mt-3 text-muted-foreground">Please email <a href="mailto:hello@craftcebu.test" class="text-primary underline">hello@craftcebu.test</a> to talk about reopening it.</p>
    </div>
  </div>
</template>
