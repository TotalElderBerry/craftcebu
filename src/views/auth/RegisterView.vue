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

const auth = useAuthStore()
const router = useRouter()

const fullName = ref('')
const email = ref('')
const password = ref('')
const confirm = ref('')
const error = ref('')
const loading = ref(false)
const needsConfirmation = ref(false)

async function submit() {
  error.value = ''
  if (password.value.length < 8) {
    error.value = 'Use at least 8 characters for your password.'
    return
  }
  if (password.value !== confirm.value) {
    error.value = 'Passwords do not match.'
    return
  }
  loading.value = true
  try {
    needsConfirmation.value = await auth.signUp(fullName.value.trim(), email.value.trim(), password.value)
    if (!needsConfirmation.value) {
      toast.success('Account created. Maayong pag-abot!')
      router.push('/')
    }
  }
  catch (e) {
    error.value = e instanceof Error ? e.message : 'Could not create account'
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Create an account" description="Shop handmade crafts from Cebuano artisans.">
    <Alert v-if="needsConfirmation">
      <AlertDescription>
        Check <strong>{{ email }}</strong> for a confirmation link, then log in.
      </AlertDescription>
    </Alert>
    <form v-else class="grid gap-4" @submit.prevent="submit">
      <Alert v-if="error" variant="destructive">
        <AlertDescription>{{ error }}</AlertDescription>
      </Alert>
      <div class="grid gap-2">
        <Label for="name">Full name</Label>
        <Input id="name" v-model="fullName" autocomplete="name" required />
      </div>
      <div class="grid gap-2">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" autocomplete="email" required />
      </div>
      <div class="grid gap-2">
        <Label for="password">Password</Label>
        <Input id="password" v-model="password" type="password" autocomplete="new-password" required />
      </div>
      <div class="grid gap-2">
        <Label for="confirm">Confirm password</Label>
        <Input id="confirm" v-model="confirm" type="password" autocomplete="new-password" required />
      </div>
      <Button type="submit" size="lg" class="mt-2 w-full" :disabled="loading">{{ loading ? 'Creating account…' : 'Create account' }}</Button>
    </form>
    <template #footer>
      Already have an account?&nbsp;<RouterLink to="/login" class="font-medium text-primary hover:underline">Log in</RouterLink>
    </template>
  </AuthCard>
</template>
