<script setup lang="ts">
import { confirmAction } from '@/lib/confirm'
import type { AdminUser } from '@/lib/admin'
import type { UserRole } from '@/types/database'
import { SearchIcon } from '@lucide/vue'
import { computed, onMounted, ref } from 'vue'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import { Button } from '@/components/ui/button'
import { fetchUsers, setBanned } from '@/lib/admin'
import { cn } from '@/lib/utils'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const rows = ref<AdminUser[]>([])
const loading = ref(true)
const tab = ref<'all' | UserRole | 'banned'>('all')
const search = ref('')
const busy = ref<string | null>(null)

onMounted(async () => {
  try {
    rows.value = await fetchUsers()
  }
  finally {
    loading.value = false
  }
})

const match = (u: AdminUser) => tab.value === 'all' || (tab.value === 'banned' ? u.is_banned : u.role === tab.value)
const visible = computed(() => {
  const q = search.value.trim().toLowerCase()
  return rows.value.filter(u => match(u) && (!q || u.full_name.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q)))
})
const count = (t: typeof tab.value) => rows.value.filter(u => t === 'all' || (t === 'banned' ? u.is_banned : u.role === t)).length

async function toggle(u: AdminUser) {
  const ban = !u.is_banned
  if (ban && !await confirmAction({ title: `Ban ${u.full_name || u.email}?`, body: 'They\'re signed out and can\'t place orders until you unban them.', confirmLabel: 'Ban', destructive: true })) return
  busy.value = u.id
  try {
    await setBanned(u.id, ban)
    u.is_banned = ban
    toast.success(ban ? 'User banned.' : 'User unbanned.')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not update the user')
  }
  finally {
    busy.value = null
  }
}

const roleTone: Record<UserRole, string> = {
  owner: 'bg-primary/10 text-primary',
  artisan: 'bg-mango/40 text-ink',
  buyer: 'bg-secondary text-muted-foreground',
}
</script>

<template>
  <div class="mx-auto max-w-7xl">
    <AdminCard title="Users" :subtitle="`${rows.length} accounts`">
      <template #actions>
        <label class="flex h-10 items-center gap-2 rounded-md border px-3 text-sm">
          <SearchIcon class="size-4 text-muted-foreground" />
          <input v-model="search" type="search" placeholder="Name or email" aria-label="Search users" class="w-full min-w-0 bg-transparent outline-none sm:w-44">
        </label>
      </template>
      <template #tabs>
        <TabButton :active="tab === 'all'" :count="count('all')" @select="tab = 'all'">All</TabButton>
        <TabButton :active="tab === 'buyer'" :count="count('buyer')" @select="tab = 'buyer'">Buyers</TabButton>
        <TabButton :active="tab === 'artisan'" :count="count('artisan')" @select="tab = 'artisan'">Artisans</TabButton>
        <TabButton :active="tab === 'banned'" :count="count('banned')" @select="tab = 'banned'">Banned</TabButton>
      </template>
      <div class="overflow-x-auto">
        <table class="w-full min-w-[680px] text-sm">
          <thead class="bg-secondary/60 text-left text-xs text-muted-foreground">
            <tr>
              <th class="px-5 py-3 font-medium">Name</th>
              <th class="px-5 py-3 font-medium">Role</th>
              <th class="px-5 py-3 font-medium">Joined</th>
              <th class="px-5 py-3 font-medium">Status</th>
              <th class="px-5 py-3 text-right font-medium">Action</th>
            </tr>
          </thead>
          <tbody class="divide-y">
            <tr v-if="loading"><td colspan="5" class="px-5 py-10 text-center text-muted-foreground">Loading…</td></tr>
            <tr v-else-if="!visible.length"><td colspan="5" class="px-5 py-12 text-center text-muted-foreground">No users here.</td></tr>
            <tr v-for="u in visible" v-else :key="u.id" class="hover:bg-secondary/40">
              <td class="px-5 py-3">
                <p class="font-medium">{{ u.full_name || '(no name)' }}</p>
                <p class="text-xs text-muted-foreground">{{ u.email }}</p>
              </td>
              <td class="px-5 py-3"><span :class="cn('rounded-full px-2.5 py-0.5 text-xs font-medium capitalize', roleTone[u.role])">{{ u.role }}</span></td>
              <td class="px-5 py-3 text-muted-foreground">{{ new Date(u.created_at).toLocaleDateString('en-PH', { month: 'short', day: 'numeric', year: 'numeric' }) }}</td>
              <td class="px-5 py-3"><span :class="u.is_banned ? 'font-medium text-destructive' : 'text-muted-foreground'">{{ u.is_banned ? 'Banned' : 'Active' }}</span></td>
              <td class="px-5 py-3 text-right">
                <Button v-if="u.role !== 'owner' && u.id !== auth.user?.id" size="sm" variant="outline" :class="cn('rounded-full', !u.is_banned && 'text-destructive')" :disabled="busy === u.id" @click="toggle(u)">
                  {{ u.is_banned ? 'Unban' : 'Ban' }}
                </Button>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </AdminCard>
  </div>
</template>
