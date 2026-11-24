<script setup lang="ts">
import { ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AuthCard from '@/components/AuthCard.vue'
import { Alert, AlertDescription } from '@/components/ui/alert'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const route = useRoute()
const router = useRouter()

const email = ref('')
const password = ref('')
const error = ref('')
const loading = ref(false)

async function submit() {
  error.value = ''
  loading.value = true
  try {
    await auth.signIn(email.value.trim(), password.value)
    toast.success(`Maayong pag-abot${auth.profile?.full_name ? `, ${auth.profile.full_name}` : ''}!`)
    const redirect = typeof route.query.redirect === 'string' ? route.query.redirect : null
    router.push(redirect ?? (auth.isOwner ? '/admin' : '/'))
  }
  catch (e) {
    error.value = e instanceof Error ? e.message : 'Could not log in'
  }
  finally {
    loading.value = false
  }
}
</script>

<template>
  <AuthCard title="Log in" description="Maayong pagbalik. Welcome back.">
    <form class="grid gap-4" @submit.prevent="submit">
      <Alert v-if="error" variant="destructive">
        <AlertDescription>{{ error }}</AlertDescription>
      </Alert>
      <div class="grid gap-2">
        <Label for="email">Email</Label>
        <Input id="email" v-model="email" type="email" autocomplete="email" required />
      </div>
      <div class="grid gap-2">
        <div class="flex items-center justify-between">
          <Label for="password">Password</Label>
          <RouterLink to="/forgot-password" class="-my-2 py-2 text-sm text-primary hover:underline">Forgot password?</RouterLink>
        </div>
        <Input id="password" v-model="password" type="password" autocomplete="current-password" required />
      </div>
      <Button type="submit" size="lg" class="mt-2 w-full" :disabled="loading">{{ loading ? 'Logging in…' : 'Log in' }}</Button>
    </form>
    <template #footer>
      New to CraftCebu?&nbsp;<RouterLink to="/register" class="font-medium text-primary hover:underline">Create an account</RouterLink>
    </template>
  </AuthCard>
</template>
