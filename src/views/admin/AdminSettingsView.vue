<script setup lang="ts">
import { onMounted, reactive, ref } from 'vue'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { fetchSettings, saveSetting } from '@/lib/admin'

const form = reactive({ commission: '', shipping: '', name: '', email: '', phone: '' })
const saving = ref(false)
const loaded = ref(false)

onMounted(async () => {
  const s = await fetchSettings()
  const store = (s.store ?? {}) as { name?: string, email?: string, phone?: string }
  Object.assign(form, {
    commission: String(s.commission_percent ?? 5),
    shipping: String(s.shipping_fee_per_shop ?? 50),
    name: store.name ?? 'CraftCebu',
    email: store.email ?? '',
    phone: store.phone ?? '',
  })
  loaded.value = true
})

async function save() {
  const commission = Number(form.commission)
  const shipping = Number(form.shipping)
  if (!(commission >= 0 && commission <= 50)) return toast.error('Commission must be between 0 and 50%.')
  if (!(shipping >= 0 && shipping <= 1000)) return toast.error('Shipping fee must be between ₱0 and ₱1,000.')
  saving.value = true
  try {
    await Promise.all([
      saveSetting('commission_percent', commission),
      saveSetting('shipping_fee_per_shop', shipping),
      saveSetting('store', { name: form.name.trim(), email: form.email.trim(), phone: form.phone.trim() }),
    ])
    toast.success('Settings saved. New orders use the new rates.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save settings')
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl">
    <AdminCard title="Settings" subtitle="Changes apply to new orders; past orders keep the rates they were placed with.">
      <div v-if="!loaded" class="m-5 h-64 animate-pulse rounded bg-muted" />
      <form v-else class="grid gap-6 p-5" @submit.prevent="save">
        <section class="grid gap-4 sm:grid-cols-2">
          <div class="grid gap-2">
            <Label for="commission">Platform commission (%)</Label>
            <Input id="commission" v-model="form.commission" type="number" min="0" max="50" step="0.5" required />
            <p class="text-xs text-muted-foreground">Taken from each shop's subtotal.</p>
          </div>
          <div class="grid gap-2">
            <Label for="shipping">Shipping fee per shop (₱)</Label>
            <Input id="shipping" v-model="form.shipping" type="number" min="0" max="1000" step="1" required />
            <p class="text-xs text-muted-foreground">Charged once for each shop in an order.</p>
          </div>
        </section>
        <section class="grid gap-4 border-t pt-6 sm:grid-cols-3">
          <div class="grid gap-2"><Label for="store-name">Store name</Label><Input id="store-name" v-model="form.name" required /></div>
          <div class="grid gap-2"><Label for="store-email">Contact email</Label><Input id="store-email" v-model="form.email" type="email" /></div>
          <div class="grid gap-2"><Label for="store-phone">Contact phone</Label><Input id="store-phone" v-model="form.phone" /></div>
        </section>
        <Button type="submit" class="justify-self-start" :disabled="saving">{{ saving ? 'Saving…' : 'Save settings' }}</Button>
      </form>
    </AdminCard>
  </div>
</template>
