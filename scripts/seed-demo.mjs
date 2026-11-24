// Demo catalog for presentations: four verified demo shops with products.
//
//   npm run seed:demo            add or refresh the demo shops
//   npm run seed:demo -- --remove   delete every demo shop and its products
//
// Needs SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local and the
// starter data from supabase/seed.sql. Demo accounts use @craftcebu.test
// addresses and random passwords; nobody signs in as them.
import { randomBytes } from 'node:crypto'
import { createClient } from '@supabase/supabase-js'

const { SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY } = process.env
if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
  console.error('Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY in .env.local')
  process.exit(1)
}

const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
})

// Unsplash stand-in photos (Unsplash License), same set as src/lib/images.ts.
const photo = (id, w = 900) => `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${w}&q=80`

const shops = [
  {
    email: 'demo-argao-loom@craftcebu.test',
    owner: 'Demo Weaver',
    shop_name: 'Argao Loom House',
    slug: 'argao-loom-house',
    town: 'Argao',
    craft_since: 1998,
    photo_url: photo('1759719441268-7d807f21a4ea', 600),
    story: 'A family weaving shop keeping Argao\'s hablon tradition on wooden looms. Each piece is woven thread by thread in bright stripes and checks.\n\nThis is a demo shop for the CraftCebu capstone presentation.',
    products: [
      { name: 'Hablon Table Runner', category: 'hablon-weaving', price: 850, stock: 12, materials: 'Cotton, abaca blend', description: 'A striped runner handwoven on a wooden loom, sized for a six-seater table.', images: ['1592914486106-fa452cfc092c'] },
      { name: 'Hablon Shawl', category: 'hablon-weaving', price: 1200, stock: 6, materials: 'Cotton', description: 'A lightweight shawl in classic Argao checks. Soft enough for everyday wear.', images: ['1643766882273-335aae5a9309', '1592914486106-fa452cfc092c'] },
      { name: 'Woven Coin Purse', category: 'fashion-accessories', price: 280, stock: 30, materials: 'Hablon cloth, zipper', description: 'A small zip purse cut from hablon offcuts, so no thread goes to waste.', images: ['1758784881676-68e4b9e26da2'] },
      { name: 'Hablon Throw Pillow Cover', category: 'hablon-weaving', price: 650, stock: 4, materials: 'Cotton', description: 'An 18-inch cover with a hidden zip, woven in warm red and gold.', images: ['1707978932202-751b08324daf'] },
    ],
  },
  {
    email: 'demo-mandaue-uway@craftcebu.test',
    owner: 'Demo Rattan Maker',
    shop_name: 'Mandaue Uway Works',
    slug: 'mandaue-uway-works',
    town: 'Mandaue City',
    craft_since: 2005,
    photo_url: photo('1534953342533-7711c98712be', 600),
    story: 'A small rattan workshop in Mandaue weaving bags, baskets and home pieces by hand from locally sourced uway.\n\nThis is a demo shop for the CraftCebu capstone presentation.',
    products: [
      { name: 'Rattan Market Tote', category: 'rattan-wicker', price: 1450, stock: 8, materials: 'Rattan, leather handles', description: 'A sturdy everyday tote with a tight weave and leather handles.', images: ['1524679813234-66a389fe1a42'] },
      { name: 'Nesting Baskets, Set of 3', category: 'rattan-wicker', price: 1800, stock: 5, materials: 'Rattan', description: 'Three baskets that stack inside each other for storage or display.', images: ['1601330862030-1e08c703ac04', '1758784881676-68e4b9e26da2'] },
      { name: 'Wicker Fruit Bowl', category: 'rattan-wicker', price: 520, stock: 0, materials: 'Wicker', description: 'A wide, shallow bowl woven in a spiral. Currently sold out.', images: ['1777332546255-818d0cc8aff9'] },
      { name: 'Woven Wall Plate', category: 'rattan-wicker', price: 390, stock: 15, materials: 'Rattan', description: 'A round woven plate for walls; group a few for a statement display.', images: ['1789655467898-d0a0211455ed'] },
    ],
  },
  {
    email: 'demo-maribago-strings@craftcebu.test',
    owner: 'Demo Luthier',
    shop_name: 'Maribago Strings',
    slug: 'maribago-strings',
    town: 'Lapu-Lapu City',
    craft_since: 1990,
    photo_url: photo('1760413209533-c65c9e6b538f', 600),
    story: 'Guitars and ukuleles built by hand in Lapu-Lapu, from shaping the body to setting the strings.\n\nThis is a demo shop for the CraftCebu capstone presentation.',
    products: [
      { name: 'Classical Guitar', category: 'guitars-instruments', price: 9500, stock: 3, materials: 'Narra back and sides, spruce top', description: 'A full-size nylon-string guitar with a warm, rounded tone.', images: ['1607513272385-b4f42e08fb16', '1760413209533-c65c9e6b538f'] },
      { name: 'Soprano Ukulele', category: 'guitars-instruments', price: 2800, stock: 10, materials: 'Mahogany', description: 'A bright, easy-to-play ukulele, a favorite for beginners and gifts.', images: ['1758002102952-6d61ea980980'] },
      { name: 'Concert Ukulele', category: 'guitars-instruments', price: 3900, stock: 2, materials: 'Acacia', description: 'A slightly larger ukulele with a fuller sound and figured wood.', images: ['1621875833619-370c48ffa953'] },
    ],
  },
  {
    email: 'demo-mactan-kinhason@craftcebu.test',
    owner: 'Demo Shell Crafter',
    shop_name: 'Mactan Kinhason Studio',
    slug: 'mactan-kinhason-studio',
    town: 'Lapu-Lapu City',
    craft_since: 2012,
    photo_url: photo('1765077613984-87e023a96501', 600),
    story: 'Jewelry and home pieces made from shells, finished and strung by hand on Mactan.\n\nThis is a demo shop for the CraftCebu capstone presentation.',
    products: [
      { name: 'Scallop Shell Necklace', category: 'shell-craft', price: 450, stock: 20, materials: 'Scallop shells, cotton cord', description: 'A light necklace of polished scallop shells on an adjustable cord.', images: ['1745192896602-e64f0e1e428d'] },
      { name: 'Shell Wind Chime', category: 'shell-craft', price: 750, stock: 7, materials: 'Shells, driftwood', description: 'A hanging chime of shells and driftwood that sounds like the shore.', images: ['1765077613984-87e023a96501'] },
      { name: 'Cowrie Shell Bracelet', category: 'fashion-accessories', price: 220, stock: 25, materials: 'Cowrie shells, elastic', description: 'A stretch bracelet of cowrie shells, one size fits most.', images: ['1761643632461-e32354eabb97'] },
    ],
  },
]

const slugify = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/(^-|-$)/g, '')

async function findUser(email) {
  for (let page = 1; ; page++) {
    const { data, error } = await admin.auth.admin.listUsers({ page, perPage: 200 })
    if (error) throw error
    const user = data.users.find(u => u.email === email)
    if (user) return user
    if (data.users.length < 200) return null
  }
}

async function remove() {
  for (const shop of shops) {
    const user = await findUser(shop.email)
    if (!user) continue
    // Deleting the account cascades to its profile, shop, products and images.
    const { error } = await admin.auth.admin.deleteUser(user.id)
    if (error) throw error
    console.log(`Removed ${shop.shop_name}`)
  }
}

async function seed() {
  const [{ data: towns, error: tErr }, { data: categories, error: cErr }] = await Promise.all([
    admin.from('towns').select('id, name'),
    admin.from('categories').select('id, slug'),
  ])
  if (tErr || cErr) throw tErr ?? cErr
  if (!towns.length || !categories.length) {
    console.error('Run supabase/seed.sql first (towns and categories are empty).')
    process.exit(1)
  }
  const townId = name => towns.find(t => t.name === name)?.id ?? null
  const categoryId = slug => categories.find(c => c.slug === slug)?.id ?? null

  for (const shop of shops) {
    let user = await findUser(shop.email)
    if (!user) {
      const { data, error } = await admin.auth.admin.createUser({
        email: shop.email,
        password: randomBytes(24).toString('base64url'),
        email_confirm: true,
        user_metadata: { full_name: shop.owner },
      })
      if (error) throw error
      user = data.user
    }

    const { error: pErr } = await admin.from('profiles').update({ role: 'artisan', full_name: shop.owner }).eq('id', user.id)
    if (pErr) throw pErr

    const { data: artisan, error: aErr } = await admin.from('artisans').upsert({
      profile_id: user.id,
      shop_name: shop.shop_name,
      slug: shop.slug,
      story: shop.story,
      town_id: townId(shop.town),
      craft_since: shop.craft_since,
      photo_url: shop.photo_url,
      status: 'verified',
      verified_at: new Date().toISOString(),
    }, { onConflict: 'profile_id' }).select('id').single()
    if (aErr) throw aErr

    for (const item of shop.products) {
      const { data: product, error: prErr } = await admin.from('products').upsert({
        artisan_id: artisan.id,
        category_id: categoryId(item.category),
        name: item.name,
        slug: `${slugify(item.name)}-${shop.slug.split('-')[0]}`,
        description: item.description,
        materials: item.materials,
        price: item.price,
        stock: item.stock,
        is_active: true,
      }, { onConflict: 'slug' }).select('id').single()
      if (prErr) throw prErr

      await admin.from('product_images').delete().eq('product_id', product.id)
      const { error: iErr } = await admin.from('product_images').insert(
        item.images.map((id, i) => ({ product_id: product.id, url: photo(id), sort_order: i })),
      )
      if (iErr) throw iErr
    }
    console.log(`Seeded ${shop.shop_name} (${shop.products.length} products)`)
  }
}

try {
  if (process.argv.includes('--remove')) await remove()
  else await seed()
}
catch (e) {
  console.error('Demo seed failed:', e.message ?? e)
  process.exit(1)
}
