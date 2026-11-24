<script setup lang="ts">
import { ref } from 'vue'
import { toast } from 'vue-sonner'
import StarPicker from '@/components/StarPicker.vue'
import { Button } from '@/components/ui/button'
import { Textarea } from '@/components/ui/textarea'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

// The database only accepts a review from the buyer of a delivered item, once.
const props = defineProps<{ productId: string, orderItemId: string, productName: string }>()
const emit = defineEmits<{ saved: [review: { id: string, order_item_id: string, rating: number, comment: string }], cancel: [] }>()

const auth = useAuthStore()
const rating = ref(0)
const comment = ref('')
const saving = ref(false)

async function submit() {
  if (!rating.value) return toast.error('Choose a star rating.')
  saving.value = true
  try {
    const { data, error } = await supabase
      .from('reviews')
      .insert({ product_id: props.productId, order_item_id: props.orderItemId, buyer_id: auth.user!.id, rating: rating.value, comment: comment.value.trim() })
      .select('id, order_item_id, rating, comment')
      .single()
    if (error) throw error
    toast.success('Salamat sa imong review! Thanks for your review.')
    emit('saved', data)
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save your review')
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <form class="grid gap-3 rounded-lg bg-secondary p-4" @submit.prevent="submit">
    <p class="text-sm font-medium">How was the {{ productName }}?</p>
    <StarPicker v-model="rating" />
    <Textarea v-model="comment" rows="3" maxlength="1000" placeholder="What did you like? How's the quality? (optional)" aria-label="Your review" />
    <div class="flex gap-2">
      <Button type="submit" size="sm" class="rounded-full" :disabled="saving">{{ saving ? 'Posting…' : 'Post review' }}</Button>
      <Button type="button" size="sm" variant="ghost" class="rounded-full" @click="emit('cancel')">Cancel</Button>
    </div>
  </form>
</template>
