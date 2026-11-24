<script setup lang="ts">
import type { AddressInput } from '@/lib/orders'
import { reactive, ref } from 'vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'

defineProps<{ saving?: boolean, cancellable?: boolean }>()
const emit = defineEmits<{ submit: [input: AddressInput, makeDefault: boolean], cancel: [] }>()

const form = reactive({ recipient: '', phone: '', street: '', barangay: '', city: '', province: 'Cebu' })
const makeDefault = ref(true)
const error = ref('')

function submit() {
  // Philippine mobile numbers: 09XXXXXXXXX or +639XXXXXXXXX.
  if (!/^(09|\+639)\d{9}$/.test(form.phone.replace(/[\s-]/g, ''))) {
    error.value = 'Enter a mobile number like 0917 123 4567.'
    return
  }
  error.value = ''
  emit('submit', { ...form, phone: form.phone.replace(/[\s-]/g, '') }, makeDefault.value)
}
</script>

<template>
  <form class="grid gap-4" @submit.prevent="submit">
    <div class="grid gap-4 sm:grid-cols-2">
      <div class="grid gap-2"><Label for="recipient">Full name</Label><Input id="recipient" v-model="form.recipient" required autocomplete="name" /></div>
      <div class="grid gap-2"><Label for="phone">Mobile number</Label><Input id="phone" v-model="form.phone" required autocomplete="tel" placeholder="0917 123 4567" /></div>
    </div>
    <div class="grid gap-2"><Label for="street">House no., street, building</Label><Input id="street" v-model="form.street" required autocomplete="address-line1" /></div>
    <div class="grid gap-4 sm:grid-cols-3">
      <div class="grid gap-2"><Label for="barangay">Barangay</Label><Input id="barangay" v-model="form.barangay" required /></div>
      <div class="grid gap-2"><Label for="city">City / municipality</Label><Input id="city" v-model="form.city" required autocomplete="address-level2" /></div>
      <div class="grid gap-2"><Label for="province">Province</Label><Input id="province" v-model="form.province" required autocomplete="address-level1" /></div>
    </div>
    <label class="flex items-center gap-2 text-sm"><input v-model="makeDefault" type="checkbox" class="size-4 accent-[var(--primary)]"> Use as my default address</label>
    <p v-if="error" class="text-sm text-destructive">{{ error }}</p>
    <div class="flex gap-2">
      <Button type="submit" :disabled="saving">{{ saving ? 'Saving…' : 'Save address' }}</Button>
      <Button v-if="cancellable" type="button" variant="outline" @click="emit('cancel')">Cancel</Button>
    </div>
  </form>
</template>
