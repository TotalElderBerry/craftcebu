// Stand-in photography from Unsplash, the same as src/lib/images.ts, until a
// shop uploads its own photos.
String _unsplash(String id, [int w = 1200]) => 'https://images.unsplash.com/photo-$id?auto=format&fit=crop&w=$w&q=80';

final _byCategory = {
  'hablon-weaving': _unsplash('1592914486106-fa452cfc092c', 600),
  'rattan-wicker': _unsplash('1524679813234-66a389fe1a42', 600),
  'shell-craft': _unsplash('1745192896602-e64f0e1e428d', 600),
  'guitars-instruments': _unsplash('1758002102952-6d61ea980980', 600),
  'woodcarving': _unsplash('1759523121247-76be6b3490b2', 600),
  'pottery': _unsplash('1468322638156-074863f9362e', 600),
  'fashion-accessories': _unsplash('1758784881676-68e4b9e26da2', 600),
  'pasalubong': _unsplash('1601330862030-1e08c703ac04', 600),
};

final _wovenTexture = _unsplash('1777332546255-818d0cc8aff9', 900);

String standInFor(String? categorySlug) => _byCategory[categorySlug] ?? _wovenTexture;
