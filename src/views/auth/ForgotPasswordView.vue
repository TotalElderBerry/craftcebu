<script setup lang="ts">
import { ref } from 'vue'
import AuthCard from '@/components/AuthCard.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const email = ref('')
const error = ref('')
const sent = ref(false)
const loading = ref(false)

async function submit() {
  error.value = ''
  loading.value = true
  try {
    await auth.sendPasswordReset(email.value.trim())
    sent.value = true
  }
  catch (e) {
    error.value = e instanceof Error ? e.message : 'Could not send reset email'
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Forgot password" description="We'll email you a link to set a new one.">
    <Alert v-if="sent">
      <AlertDescription>If an account exists for <strong>{{ email }}</strong>, a reset link is on its way.</AlertDescription>
    </Alert>
    <form v-else class="grid gap-4" @submit.prevent="submit">
      <Alert v-if="error" variant="destructive">
        <AlertDescription>{{ error }}</AlertDescription>
      </Alert>
      <div class="grid gap-2">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" autocomplete="email" required />
      </div>
      <Button type="submit" size="lg" class="mt-2 w-full" :disabled="loading">{{ loading ? 'Sending…' : 'Send reset link' }}</Button>
    </form>
    <template #footer>
      <RouterLink to="/login" class="font-medium text-primary hover:underline">Back to log in</RouterLink>
    </template>
  </AuthCard>
</template>
