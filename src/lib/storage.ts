import { supabase } from '@/lib/supabase'

export type ImageBucket = 'product-images' | 'artisan-photos' | 'banners'

const MAX_BYTES = 5 * 1024 * 1024
const ALLOWED = ['image/jpeg', 'image/png', 'image/webp']

export function validateImage(file: File) {
  if (!ALLOWED.includes(file.type)) return 'Use a JPG, PNG or WebP image.'
  if (file.size > MAX_BYTES) return 'Each image must be 5 MB or smaller.'
  return null
}

// Uploads into the signed-in user's own folder (storage policies require it)
// and returns the public URL.
export async function uploadImage(bucket: ImageBucket, file: File, userId: string) {
  const problem = validateImage(file)
  if (problem) throw new Error(problem)
  const ext = file.name.split('.').pop()?.toLowerCase() || 'jpg'
  const path = `${userId}/${crypto.randomUUID()}.${ext}`
  const { error } = await supabase.storage.from(bucket).upload(path, file, { contentType: file.type })
  if (error) throw error
  return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl
}

// Best effort: a leftover file only costs storage, so failures are ignored.
export async function removeImage(bucket: ImageBucket, publicUrl: string) {
  const marker = `/storage/v1/object/public/${bucket}/`
  const at = publicUrl.indexOf(marker)
  if (at === -1) return
  await supabase.storage.from(bucket).remove([publicUrl.slice(at + marker.length)])
}
