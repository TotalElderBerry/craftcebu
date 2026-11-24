<script setup lang="ts">
import { ref, watchEffect } from 'vue'
import { toast } from 'vue-sonner'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { supabase } from '@/lib/supabase'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const fullName = ref('')
const saving = ref(false)

watchEffect(() => {
  fullName.value = auth.profile?.full_name ?? ''
})

async function save() {
  if (!auth.user) return
  saving.value = true
  const { error } = await supabase.from('profiles').update({ full_name: fullName.value.trim() }).eq('id', auth.user.id)
  saving.value = false
  if (error) return toast.error(error.message)
  await auth.loadProfile()
  toast.success('Profile saved.')
}
</script>

<template>
  <div class="mx-auto max-w-2xl px-4 py-16">
    <h1 class="mb-8 font-display text-5xl font-medium">My account</h1>
    <Card>
      <CardHeader>
        <CardTitle>Profile</CardTitle>
        <CardDescription class="flex items-center gap-2">
          {{ auth.user?.email }} <Badge variant="secondary" class="capitalize">{{ auth.role }}</Badge>
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form class="grid gap-4" @submit.prevent="save">
          <div class="grid gap-2">
            <Label for="name">Full name</Label>
            <Input id="name" v-model="fullName" required />
          </div>
          <Button type="submit" class="justify-self-start" :disabled="saving">{{ saving ? 'Saving…' : 'Save' }}</Button>
        </form>
      </CardContent>
    </Card>
    <p class="mt-6 text-sm text-muted-foreground">Follow your orders in <RouterLink to="/orders" class="font-medium text-primary hover:underline">My purchases</RouterLink>.</p>
  </div>
</template>
