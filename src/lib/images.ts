// Stand-in photography from Unsplash (free to use under the Unsplash License,
// https://unsplash.com/license). Replace with real CRAFTCEBU artisan photos
// once shops upload their own.
const unsplash = (id: string, w = 1200) =>
  `https://images.unsplash.com/photo-${id}?auto=format&fit=crop&w=${w}&q=80`

export const images = {
  hero: unsplash('1601330862030-1e08c703ac04', 1000), // woven baskets
  weavingHands: unsplash('1534953342533-7711c98712be'), // hands weaving straw
  loom: unsplash('1759719441268-7d807f21a4ea'), // weaver at a loom
  pottery: unsplash('1493106641515-6b5631de4bb9'), // shaping a vase
  guitars: unsplash('1760413209533-c65c9e6b538f', 1600), // guitar workshop wall
  wovenTexture: unsplash('1777332546255-818d0cc8aff9', 900),
}

// One photo per craft category, keyed by categories.slug.
export const categoryImages: Record<string, string> = {
  'hablon-weaving': unsplash('1592914486106-fa452cfc092c', 600),
  'rattan-wicker': unsplash('1524679813234-66a389fe1a42', 600),
  'shell-craft': unsplash('1745192896602-e64f0e1e428d', 600),
  'guitars-instruments': unsplash('1758002102952-6d61ea980980', 600),
  'woodcarving': unsplash('1759523121247-76be6b3490b2', 600),
  'pottery': unsplash('1468322638156-074863f9362e', 600),
  'fashion-accessories': unsplash('1758784881676-68e4b9e26da2', 600),
  'pasalubong': unsplash('1601330862030-1e08c703ac04', 600),
}
