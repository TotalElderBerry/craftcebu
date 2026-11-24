<script setup lang="ts">
import type { ImageBucket } from '@/lib/storage'
import { ImagePlusIcon, Loader2Icon, StarIcon, XIcon } from '@lucide/vue'
import { ref } from 'vue'
import { toast } from 'vue-sonner'
import { uploadImage, validateImage } from '@/lib/storage'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'

const props = withDefaults(defineProps<{
  bucket: ImageBucket
  max?: number
  // Product photos: the first image is the cover and can be changed.
  coverLabel?: boolean
  shape?: 'square' | 'arch'
}>(), { max: 6, coverLabel: false, shape: 'square' })

const urls = defineModel<string[]>({ required: true })
const auth = useAuthStore()
const uploading = ref(0)
const input = ref<HTMLInputElement | null>(null)

async function onFiles(event: Event) {
  const files = [...((event.target as HTMLInputElement).files ?? [])]
  ;(event.target as HTMLInputElement).value = ''
  const room = props.max - urls.value.length
  if (files.length > room) toast.warning(`You can add ${room} more ${room === 1 ? 'photo' : 'photos'}.`)
  for (const file of files.slice(0, room)) {
    const problem = validateImage(file)
    if (problem) {
      toast.error(`${file.name}: ${problem}`)
      continue
    }
    uploading.value++
    try {
      const url = await uploadImage(props.bucket, file, auth.user!.id)
      urls.value = [...urls.value, url]
    }
    catch (e) {
      toast.error((e as { message?: string }).message ?? 'Upload failed')
    }
    finally {
      uploading.value--
    }
  }
}

function remove(i: number) {
  urls.value = urls.value.filter((_, j) => j !== i)
}

function makeCover(i: number) {
  const next = [...urls.value]
  const [picked] = next.splice(i, 1)
  urls.value = [picked!, ...next]
}

const frame = props.shape === 'arch' ? 'rounded-t-[999px] rounded-b-lg aspect-[3/4]' : 'rounded-lg aspect-square'
</script>

<template>
  <div class="flex flex-wrap gap-3">
    <div v-for="(url, i) in urls" :key="url" :class="cn('group relative w-28 overflow-hidden border bg-muted', frame)">
      <img :src="url" alt="" class="size-full object-cover">
      <span v-if="coverLabel && i === 0" class="absolute bottom-1.5 left-1.5 rounded-full bg-ink/80 px-2 py-0.5 text-[0.65rem] font-semibold text-white">Cover</span>
      <!-- Always shown on touch screens; revealed on hover where a mouse exists -->
      <div class="absolute top-1.5 right-1.5 flex gap-1 transition-opacity [@media(hover:hover)]:opacity-0 [@media(hover:hover)]:group-focus-within:opacity-100 [@media(hover:hover)]:group-hover:opacity-100">
        <button v-if="coverLabel && i > 0" type="button" class="grid size-8 place-items-center rounded-full bg-background/95 shadow" aria-label="Make cover photo" title="Make cover photo" @click="makeCover(i)">
          <StarIcon class="size-3.5" />
        </button>
        <button type="button" class="grid size-8 place-items-center rounded-full bg-background/95 shadow" aria-label="Remove photo" @click="remove(i)">
          <XIcon class="size-3.5" />
        </button>
      </div>
    </div>

    <div v-for="n in uploading" :key="`u${n}`" :class="cn('grid w-28 place-items-center border border-dashed bg-muted', frame)">
      <Loader2Icon class="size-5 animate-spin text-muted-foreground" />
    </div>

    <button
      v-if="urls.length + uploading < max"
      type="button"
      :class="cn('flex w-28 flex-col items-center justify-center gap-1.5 border border-dashed text-xs text-muted-foreground transition-colors hover:border-primary hover:text-primary', frame)"
      @click="input?.click()"
    >
      <ImagePlusIcon class="size-5" />
      Add photo
    </button>
    <input ref="input" type="file" accept="image/jpeg,image/png,image/webp" :multiple="max > 1" class="sr-only" tabindex="-1" @change="onFiles">
  </div>
</template>
