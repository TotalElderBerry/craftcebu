<script setup lang="ts">
import type { Category, Town } from '@/types/database'
import { PencilIcon, PlusIcon, Trash2Icon } from '@lucide/vue'
import { onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import AdminCard from '@/components/admin/AdminCard.vue'
import TabButton from '@/components/admin/TabButton.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { deleteCategory, deleteTown, fetchCategoriesWithCounts, fetchTownsWithCounts, saveCategory, saveTown } from '@/lib/admin'
import { slugify } from '@/lib/slug'

const route = useRoute()
const router = useRouter()
const tab = ref<'crafts' | 'towns'>(route.query.tab === 'towns' ? 'towns' : 'crafts')
const categories = ref<Awaited<ReturnType<typeof fetchCategoriesWithCounts>>>([])
const towns = ref<Awaited<ReturnType<typeof fetchTownsWithCounts>>>([])
const saving = ref(false)

async function load() {
  ;[categories.value, towns.value] = await Promise.all([fetchCategoriesWithCounts(), fetchTownsWithCounts()])
}
onMounted(load)

function selectTab(t: 'crafts' | 'towns') {
  tab.value = t
  router.replace({ query: t === 'towns' ? { tab: 'towns' } : {} })
}

// One form serves add and edit; editingId is null when adding.
const craft = reactive({ open: false, id: null as number | null, name: '' })
const town = reactive({ open: false, id: null as number | null, name: '', known_for: '', lat: '', lng: '' })

function editCraft(c?: Category) {
  Object.assign(craft, { open: true, id: c?.id ?? null, name: c?.name ?? '' })
}
function editTown(t?: Town) {
  Object.assign(town, { open: true, id: t?.id ?? null, name: t?.name ?? '', known_for: t?.known_for ?? '', lat: t?.lat?.toString() ?? '', lng: t?.lng?.toString() ?? '' })
}

async function run(action: () => Promise<void>, message: string) {
  saving.value = true
  try {
    await action()
    toast.success(message)
    await load()
    return true
  }
  catch (e) {
    const msg = (e as { message?: string }).message ?? 'Could not save'
    toast.error(msg.includes('foreign key') ? 'It\'s still in use. Move its products or shops first.' : msg)
    return false
  }
  finally {
    saving.value = false
  }
}

async function submitCraft() {
  const ok = await run(() => saveCategory({ id: craft.id ?? undefined, name: craft.name.trim(), slug: slugify(craft.name) }), craft.id ? 'Craft updated.' : 'Craft added.')
  if (ok) craft.open = false
}
async function submitTown() {
  const lat = Number(town.lat)
  const lng = Number(town.lng)
  // Cebu lies roughly between 9.4-11.4 N and 123.2-124.1 E.
  if (!(lat > 9 && lat < 12 && lng > 123 && lng < 124.5)) {
    toast.error('Those coordinates aren\'t in Cebu. Copy them from Google Maps (right-click the town).')
    return
  }
  const ok = await run(() => saveTown({ id: town.id ?? undefined, name: town.name.trim(), known_for: town.known_for.trim(), lat, lng }), town.id ? 'Town updated.' : 'Town added.')
  if (ok) town.open = false
}
</script>

<template>
  <div class="mx-auto max-w-5xl">
    <AdminCard title="Catalog Setup" subtitle="The crafts and towns buyers browse by.">
      <template #actions>
        <Button v-if="tab === 'crafts'" size="sm" class="rounded-full" @click="editCraft()"><PlusIcon /> Add craft</Button>
        <Button v-else size="sm" class="rounded-full" @click="editTown()"><PlusIcon /> Add town</Button>
      </template>
      <template #tabs>
        <TabButton :active="tab === 'crafts'" :count="categories.length" @select="selectTab('crafts')">Crafts</TabButton>
        <TabButton :active="tab === 'towns'" :count="towns.length" @select="selectTab('towns')">Towns</TabButton>
      </template>

      <template v-if="tab === 'crafts'">
        <form v-if="craft.open" class="flex flex-wrap items-end gap-3 border-b bg-secondary/40 px-5 py-4" @submit.prevent="submitCraft">
          <div class="grid min-w-60 flex-1 gap-2"><Label for="craft-name">{{ craft.id ? 'Rename craft' : 'New craft' }}</Label><Input id="craft-name" v-model="craft.name" required maxlength="60" /></div>
          <Button type="submit" :disabled="saving">Save</Button>
          <Button type="button" variant="ghost" @click="craft.open = false">Cancel</Button>
        </form>
        <ul class="divide-y">
          <li v-for="c in categories" :key="c.id" class="flex items-center justify-between gap-3 px-5 py-3 text-sm">
            <span><span class="font-medium">{{ c.name }}</span> <span class="text-muted-foreground">· {{ c.products[0]?.count ?? 0 }} products</span></span>
            <span class="flex gap-1">
              <Button variant="ghost" size="icon-sm" :aria-label="`Rename ${c.name}`" @click="editCraft(c)"><PencilIcon /></Button>
              <Button variant="ghost" size="icon-sm" :aria-label="`Delete ${c.name}`" :disabled="(c.products[0]?.count ?? 0) > 0" :title="(c.products[0]?.count ?? 0) > 0 ? 'Has products' : undefined" @click="run(() => deleteCategory(c.id), 'Craft deleted.')"><Trash2Icon /></Button>
            </span>
          </li>
        </ul>
      </template>

      <template v-else>
        <form v-if="town.open" class="grid gap-3 border-b bg-secondary/40 px-5 py-4 sm:grid-cols-2" @submit.prevent="submitTown">
          <div class="grid gap-2"><Label for="town-name">Town</Label><Input id="town-name" v-model="town.name" required maxlength="60" /></div>
          <div class="grid gap-2"><Label for="town-known">Known for</Label><Input id="town-known" v-model="town.known_for" maxlength="120" placeholder="e.g. Hablon weaving, torta" /></div>
          <div class="grid gap-2"><Label for="town-lat">Latitude</Label><Input id="town-lat" v-model="town.lat" required inputmode="decimal" placeholder="9.8797" /></div>
          <div class="grid gap-2"><Label for="town-lng">Longitude</Label><Input id="town-lng" v-model="town.lng" required inputmode="decimal" placeholder="123.6075" /></div>
          <div class="flex gap-2 sm:col-span-2">
            <Button type="submit" :disabled="saving">Save town</Button>
            <Button type="button" variant="ghost" @click="town.open = false">Cancel</Button>
          </div>
        </form>
        <ul class="divide-y">
          <li v-for="t in towns" :key="t.id" class="flex items-center justify-between gap-3 px-5 py-3 text-sm">
            <span>
              <span class="font-medium">{{ t.name }}</span> <span class="text-muted-foreground">· {{ t.artisans[0]?.count ?? 0 }} shops</span>
              <span class="block text-xs text-muted-foreground">{{ t.known_for || '—' }} · {{ t.lat.toFixed(4) }}, {{ t.lng.toFixed(4) }}</span>
            </span>
            <span class="flex gap-1">
              <Button variant="ghost" size="icon-sm" :aria-label="`Edit ${t.name}`" @click="editTown(t)"><PencilIcon /></Button>
              <Button variant="ghost" size="icon-sm" :aria-label="`Delete ${t.name}`" :disabled="(t.artisans[0]?.count ?? 0) > 0" :title="(t.artisans[0]?.count ?? 0) > 0 ? 'Has shops' : undefined" @click="run(() => deleteTown(t.id), 'Town deleted.')"><Trash2Icon /></Button>
            </span>
          </li>
        </ul>
      </template>
    </AdminCard>
  </div>
</template>
