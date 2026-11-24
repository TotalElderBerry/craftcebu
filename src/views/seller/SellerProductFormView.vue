<script setup lang="ts">
import type { Category } from '@/types/database'
import { ArrowLeftIcon } from '@lucide/vue'
import { computed, onMounted, reactive, ref } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { toast } from 'vue-sonner'
import ImageUploader from '@/components/seller/ImageUploader.vue'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Switch } from '@/components/ui/switch'
import { Textarea } from '@/components/ui/textarea'
import { fetchMyProduct, saveProduct } from '@/lib/seller'
import { supabase } from '@/lib/supabase'
import { useSellerStore } from '@/stores/seller'

const route = useRoute()
const router = useRouter()
const seller = useSellerStore()

const id = computed(() => (typeof route.params.id === 'string' ? route.params.id : undefined))
const categories = ref<Pick<Category, 'id' | 'name'>[]>([])
const loading = ref(true)
const saving = ref(false)
const notFound = ref(false)

const form = reactive({
  name: '',
  category_id: '',
  description: '',
  materials: '',
  price: '',
  stock: '1',
  is_active: true,
  images: [] as string[],
})

onMounted(async () => {
  const { data } = await supabase.from('categories').select('id, name').order('id')
  categories.value = data ?? []
  if (id.value) {
    const p = await fetchMyProduct(id.value)
    if (!p) notFound.value = true
    else {
      Object.assign(form, {
        name: p.name,
        category_id: p.category_id?.toString() ?? '',
        description: p.description,
        materials: p.materials,
        price: p.price.toString(),
        stock: p.stock.toString(),
        is_active: p.is_active,
        images: [...p.images].sort((a, b) => a.sort_order - b.sort_order).map(i => i.url),
      })
    }
  }
  loading.value = false
})

async function submit() {
  const shop = seller.shop ?? await seller.load()
  if (!shop) return
  if (!form.images.length) {
    toast.error('Add at least one photo.')
    return
  }
  saving.value = true
  try {
    await saveProduct(shop.id, {
      name: form.name.trim(),
      category_id: form.category_id ? Number(form.category_id) : null,
      description: form.description.trim(),
      materials: form.materials.trim(),
      price: Number(form.price),
      stock: Number(form.stock),
      is_active: form.is_active,
    }, form.images, id.value)
    toast.success(id.value ? 'Product updated.' : form.is_active ? 'Product is live!' : 'Product saved as hidden.')
    router.push('/seller/products')
  }
  catch (e) {
    toast.error((e as { message?: string }).message ?? 'Could not save the product')
  }
  finally {
    saving.value = false
  }
}
</script>

<template>
  <div class="mx-auto max-w-3xl">
    <RouterLink to="/seller/products" class="mb-4 inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
      <ArrowLeftIcon class="size-4" /> My Products
    </RouterLink>

    <div v-if="loading" class="h-96 animate-pulse rounded-lg bg-card" />
    <div v-else-if="notFound" class="rounded-lg border bg-card p-10 text-center text-muted-foreground">This product doesn't exist or isn't yours.</div>

    <form v-else class="grid gap-4" @submit.prevent="submit">
      <section class="rounded-lg border bg-card p-5">
        <h1 class="text-lg font-semibold">{{ id ? 'Edit Product' : 'Add New Product' }}</h1>
        <p class="text-sm text-muted-foreground">Basic information</p>

        <div class="mt-5 grid gap-5">
          <div class="grid gap-2">
            <Label>Photos <span class="font-normal text-muted-foreground">(up to 6; the first is the cover)</span></Label>
            <ImageUploader v-model="form.images" bucket="product-images" :max="6" cover-label />
          </div>
          <div class="grid gap-2">
            <Label for="name">Product name</Label>
            <Input id="name" v-model="form.name" required maxlength="120" placeholder="e.g. Hablon Table Runner" />
          </div>
          <div class="grid gap-2">
            <Label for="category">Craft</Label>
            <select id="category" v-model="form.category_id" required class="h-11 rounded-lg border border-input bg-card px-3.5 text-sm">
              <option value="" disabled>Choose a craft</option>
              <option v-for="c in categories" :key="c.id" :value="c.id.toString()">{{ c.name }}</option>
            </select>
          </div>
          <div class="grid gap-2">
            <Label for="description">Description</Label>
            <Textarea id="description" v-model="form.description" rows="5" maxlength="3000" placeholder="Size, how it's made, how to care for it." />
          </div>
          <div class="grid gap-2">
            <Label for="materials">Materials</Label>
            <Input id="materials" v-model="form.materials" maxlength="200" placeholder="e.g. Cotton, abaca blend" />
          </div>
        </div>
      </section>

      <section class="rounded-lg border bg-card p-5">
        <p class="text-sm text-muted-foreground">Sales information</p>
        <div class="mt-4 grid gap-5 sm:grid-cols-2">
          <div class="grid gap-2">
            <Label for="price">Price (₱)</Label>
            <Input id="price" v-model="form.price" type="number" required min="1" step="1" placeholder="850" />
          </div>
          <div class="grid gap-2">
            <Label for="stock">Stock</Label>
            <Input id="stock" v-model="form.stock" type="number" required min="0" step="1" />
          </div>
        </div>
        <label class="mt-5 flex items-center justify-between gap-4 rounded-md bg-secondary p-4">
          <span>
            <span class="block text-sm font-medium">Show to buyers</span>
            <span class="text-xs text-muted-foreground">Turn off to keep it as a hidden draft.</span>
          </span>
          <Switch v-model="form.is_active" />
        </label>
      </section>

      <div class="flex justify-end gap-2">
        <Button type="button" variant="outline" @click="router.push('/seller/products')">Cancel</Button>
        <Button type="submit" :disabled="saving">{{ saving ? 'Saving…' : id ? 'Save changes' : 'Save and publish' }}</Button>
      </div>
    </form>
  </div>
</template>
