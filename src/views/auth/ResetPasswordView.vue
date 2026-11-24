<script setup lang="ts">
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AuthCard from '@/components/AuthCard.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuthStore } from '@/stores/auth'

// Supabase signs the user in from the emailed link, then lands them here.
const auth = useAuthStore()
const router = useRouter()
const password = ref('')
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  if (password.value.length < 8) {
    error.value = 'Use at least 8 characters for your password.'
    return
  }
  loading.value = true
  try {
    await auth.updatePassword(password.value)
    toast.success('Password updated.')
    router.push('/')
  }
  catch (e) {
    error.value = e instanceof Error ? e.message : 'Could not update password'
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Set a new password">
    <Alert v-if="!auth.user">
      <AlertDescription>Open this page from the link in your reset email.</AlertDescription>
    </Alert>
    <form v-else class="grid gap-4" @submit.prevent="submit">
      <Alert v-if="error" variant="destructive">
        <AlertDescription>{{ error }}</AlertDescription>
      </Alert>
      <div class="grid gap-2">
        <Label for="password">New password</Label>
        <Input id="password" v-model="password" type="password" autocomplete="new-password" required />
      </div>
      <Button type="submit" size="lg" class="mt-2 w-full" :disabled="loading">{{ loading ? 'Saving…' : 'Save password' }}</Button>
    </form>
  </AuthCard>
</template>
