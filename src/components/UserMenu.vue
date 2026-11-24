<script setup lang="ts">
import { HeartIcon, LayoutDashboardIcon, LogOutIcon, PackageIcon, StoreIcon, UserIcon } from '@lucide/vue'
import { computed } from 'vue'
import { useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import { Avatar, AvatarFallback } from '@/components/ui/avatar'
import { Button } from '@/components/ui/button'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'
import { useAuthStore } from '@/stores/auth'

const auth = useAuthStore()
const router = useRouter()

const name = computed(() => auth.profile?.full_name || auth.user?.email || 'Account')
const initials = computed(() =>
  name.value.split(/\s+/).map((part) => part[0]).join('').slice(0, 2).toUpperCase(),
)

async function signOut() {
  await auth.signOut()
  toast.success('Signed out. Salamat!')
  router.push({ name: 'home' })
}
</script>

<template>
  <DropdownMenu>
    <DropdownMenuTrigger as-child>
      <Button variant="ghost" class="gap-2 px-2" aria-label="Account menu">
        <Avatar class="size-7">
          <AvatarFallback class="bg-primary/10 text-xs text-primary">{{ initials }}</AvatarFallback>
        </Avatar>
        <span class="hidden max-w-32 truncate sm:inline">{{ name }}</span>
      </Button>
    </DropdownMenuTrigger>
    <DropdownMenuContent align="end" class="w-52">
      <DropdownMenuLabel class="truncate">{{ auth.user?.email }}</DropdownMenuLabel>
      <DropdownMenuSeparator />
      <DropdownMenuItem v-if="auth.isOwner" @select="router.push({ name: 'admin' })">
        <LayoutDashboardIcon /> Admin dashboard
      </DropdownMenuItem>
      <DropdownMenuItem v-if="auth.isArtisan || auth.isOwner" @select="router.push({ name: 'seller' })">
        <StoreIcon /> Seller Centre
      </DropdownMenuItem>
      <DropdownMenuItem v-else @select="router.push({ name: 'sell' })">
        <StoreIcon /> Sell on CraftCebu
      </DropdownMenuItem>
      <DropdownMenuItem @select="router.push({ name: 'orders' })">
        <PackageIcon /> My purchases
      </DropdownMenuItem>
      <DropdownMenuItem @select="router.push({ name: 'wishlist' })">
        <HeartIcon /> Saved pieces
      </DropdownMenuItem>
      <DropdownMenuItem @select="router.push({ name: 'account' })">
        <UserIcon /> My account
      </DropdownMenuItem>
      <DropdownMenuSeparator />
      <DropdownMenuItem @select="signOut">
        <LogOutIcon /> Sign out
      </DropdownMenuItem>
    </DropdownMenuContent>
  </DropdownMenu>
</template>
