<script setup lang="ts">
import type { Component } from 'vue'
import { BellIcon, ExternalLinkIcon, LayoutDashboardIcon } from '@lucide/vue'
import { useRoute } from 'vue-router'
import { Button } from '@/components/ui/button'
import UserMenu from '@/components/UserMenu.vue'
import WovenMark from '@/components/WovenMark.vue'

// The Shopee-style frame shared by the Admin Centre and the Seller Centre:
// a white top bar and a grouped sidebar. Items without `to` aren't built yet.
export interface CentreGroup {
  title: string
  icon: Component
  items: { label: string, to?: string }[]
}

const route = useRoute()

// Compare the full link, query included, so two tabs of one page (e.g. My
// Orders and Cancellations) aren't both highlighted.
const isActive = (to: string) => route.fullPath === to

defineProps<{
  name: string
  home: string
  groups: CentreGroup[]
  storeLink?: { label: string, to: string }
}>()
</script>

<template>
  <div class="flex min-h-svh flex-col bg-[oklch(0.965_0.004_80)]">
    <header class="pt-safe sticky top-0 z-40 border-b bg-card shadow-[0_1px_4px_rgba(0,0,0,0.04)]">
      <div class="flex h-14 items-center gap-3 px-4">
      <RouterLink :to="home" class="flex items-center gap-2.5">
        <WovenMark class="size-7" />
        <span class="font-display text-lg font-semibold">Craft<span class="text-primary italic">Cebu</span></span>
      </RouterLink>
      <span class="hidden h-5 w-px bg-border sm:block" aria-hidden="true" />
      <span class="hidden text-sm font-medium text-muted-foreground sm:inline">{{ name }}</span>
      <div class="ml-auto flex items-center gap-1">
        <Button variant="ghost" size="icon" aria-label="Notifications" disabled title="Notifications arrive in Milestone 6">
          <BellIcon />
        </Button>
        <Button variant="ghost" size="sm" as-child class="hidden sm:inline-flex">
          <RouterLink :to="storeLink?.to ?? '/'"><ExternalLinkIcon /> {{ storeLink?.label ?? 'View store' }}</RouterLink>
        </Button>
        <UserMenu />
      </div>
      </div>
    </header>

    <div class="flex flex-1 flex-col md:flex-row">
      <aside class="border-b bg-card md:sticky md:top-[calc(3.5rem+env(safe-area-inset-top))] md:h-[calc(100svh-3.5rem-env(safe-area-inset-top))] md:w-56 md:shrink-0 md:overflow-y-auto md:border-r md:border-b-0">
        <nav class="flex gap-1 overflow-x-auto p-2 md:flex-col md:gap-0 md:overflow-visible md:p-3" :aria-label="name">
          <RouterLink :to="home" exact-active-class="bg-primary/10 text-primary" class="flex shrink-0 items-center gap-2.5 rounded-md px-3 py-2.5 text-sm font-semibold md:py-2">
            <LayoutDashboardIcon class="size-4" /> Dashboard
          </RouterLink>
          <div v-for="g in groups" :key="g.title" class="shrink-0 md:mt-3">
            <p class="hidden items-center gap-2.5 px-3 py-2 text-sm font-semibold text-foreground/80 md:flex">
              <component :is="g.icon" class="size-4 text-muted-foreground" /> {{ g.title }}
            </p>
            <ul class="flex gap-1 md:block">
              <li v-for="item in g.items" :key="item.label">
                <RouterLink
                  v-if="item.to"
                  :to="item.to"
                  :class="['block rounded-md px-3 py-2.5 text-[0.8rem] whitespace-nowrap hover:bg-secondary md:py-1.5 md:pl-[2.6rem]', isActive(item.to) ? 'bg-primary/10 font-semibold text-primary' : 'text-foreground/80']"
                >
                  {{ item.label }}
                </RouterLink>
                <span v-else class="hidden cursor-not-allowed py-1.5 pr-3 pl-[2.6rem] text-[0.8rem] text-muted-foreground/70 md:block" title="Coming in a later milestone">
                  {{ item.label }}
                </span>
              </li>
            </ul>
          </div>
        </nav>
      </aside>

      <main class="pb-safe-4 min-w-0 flex-1 p-4 md:p-6">
        <RouterView />
      </main>
    </div>
  </div>
</template>
