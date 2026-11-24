<script setup lang="ts">
import type { ApplicationInput } from '@/lib/seller'
import type { Town } from '@/types/database'
import { onMounted, reactive, ref } from 'vue'
import ImageUploader from '@/components/seller/ImageUploader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Textarea } from '@/components/ui/textarea'
import { supabase } from '@/lib/supabase'

const props = defineProps<{
  initial?: Partial<ApplicationInput>
  submitLabel: string
  saving?: boolean
  // Applications include sample photos of the maker's work for review.
  withSamples?: boolean
}>()
const emit = defineEmits<{ submit: [input: ApplicationInput] }>()

const towns = ref<Pick<Town, 'id' | 'name'>[]>([])
onMounted(async () => {
  const { data } = await supabase.from('towns').select('id, name').order('name')
  towns.value = data ?? []
})

const thisYear = new Date().getFullYear()
const form = reactive({
  shop_name: props.initial?.shop_name ?? '',
  story: props.initial?.story ?? '',
  town_id: props.initial?.town_id?.toString() ?? '',
  craft_since: props.initial?.craft_since?.toString() ?? '',
  photo: props.initial?.photo_url ? [props.initial.photo_url] : [] as string[],
  samples: props.initial?.sample_photos ?? [] as string[],
})
const error = ref('')

function submit() {
  error.value = ''
  if (form.story.trim().length < 40) {
    error.value = 'Tell buyers a little more about yourself and your craft (at least 40 characters).'
    return
  }
  if (props.withSamples && form.samples.length < 2) {
    error.value = 'Add at least 2 photos of your work so we can review your application.'
    return
  }
  emit('submit', {
    shop_name: form.shop_name.trim(),
    story: form.story.trim(),
    town_id: form.town_id ? Number(form.town_id) : null,
    craft_since: form.craft_since ? Number(form.craft_since) : null,
    photo_url: form.photo[0] ?? null,
    sample_photos: form.samples,
  })
}
</script>

<template>
  <form class="grid gap-6" @submit.prevent="submit">
    <div class="grid gap-2">
      <Label for="shop-name">Shop name</Label>
      <Input id="shop-name" v-model="form.shop_name" required maxlength="60" placeholder="e.g. Argao Loom House" />
    </div>

    <div class="grid gap-6 sm:grid-cols-2">
      <div class="grid gap-2">
        <Label for="town">Town in Cebu</Label>
        <select id="town" v-model="form.town_id" required class="h-11 rounded-lg border border-input bg-card px-3.5 text-sm">
          <option value="" disabled>Choose your town</option>
          <option v-for="t in towns" :key="t.id" :value="t.id.toString()">{{ t.name }}</option>
        </select>
      </div>
      <div class="grid gap-2">
        <Label for="since">Practicing the craft since</Label>
        <Input id="since" v-model="form.craft_since" type="number" :min="1940" :max="thisYear" placeholder="e.g. 2005" />
      </div>
    </div>

    <div class="grid gap-2">
      <Label for="story">Your story</Label>
      <Textarea id="story" v-model="form.story" required rows="6" maxlength="2000" placeholder="Who are you, what do you make, and how did you learn the craft?" />
      <p class="text-xs text-muted-foreground">This opens your shop page, before your products. {{ form.story.length }}/2000</p>
    </div>

    <div class="grid gap-2">
      <Label>Shop photo <span class="font-normal text-muted-foreground">(you, your hands, or your workshop)</span></Label>
      <ImageUploader v-model="form.photo" bucket="artisan-photos" :max="1" shape="arch" />
    </div>

    <div v-if="withSamples" class="grid gap-2">
      <Label>Photos of your work <span class="font-normal text-muted-foreground">(2 to 6, for our review)</span></Label>
      <ImageUploader v-model="form.samples" bucket="artisan-photos" :max="6" />
    </div>

    <p v-if="error" class="rounded-lg border border-destructive/30 bg-destructive/5 p-3 text-sm text-destructive">{{ error }}</p>

    <Button type="submit" size="lg" class="justify-self-start" :disabled="saving">{{ saving ? 'Saving…' : submitLabel }}</Button>
  </form>
</template>
