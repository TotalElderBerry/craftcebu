export function slugify(text: string) {
  return text
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
    .slice(0, 60)
}

// Adds a short random suffix so two shops or products with the same name
// still get unique URLs.
export const uniqueSlug = (text: string) => `${slugify(text) || 'item'}-${Math.random().toString(36).slice(2, 7)}`
