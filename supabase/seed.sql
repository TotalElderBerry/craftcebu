-- Starter data for CRAFTCEBU: towns, craft categories and settings.
-- Safe to run more than once. Coordinates are approximate town centers;
-- the owner can adjust them later in Catalog Setup.

insert into public.towns (name, lat, lng, known_for) values
  ('Cebu City',      10.3157, 123.8854, 'Pasalubong, dried mangoes, Sto. Niño crafts'),
  ('Mandaue City',   10.3236, 123.9223, 'Furniture, rattan and wicker'),
  ('Lapu-Lapu City', 10.3103, 123.9494, 'Guitars and ukuleles, shell craft'),
  ('Carcar City',    10.1061, 123.6403, 'Leather shoes, chicharon, ampao'),
  ('Argao',           9.8797, 123.6075, 'Hablon weaving, torta'),
  ('Liloan',         10.3991, 123.9993, 'Rosquillos'),
  ('Talisay City',   10.2447, 123.8494, 'Lechon'),
  ('Bantayan',       11.1690, 123.7228, 'Dried fish, shell craft')
on conflict (name) do nothing;

insert into public.categories (name, slug, icon) values
  ('Hablon Weaving',          'hablon-weaving',     'scissors'),
  ('Rattan and Wicker',       'rattan-wicker',      'armchair'),
  ('Shell Craft',             'shell-craft',        'shell'),
  ('Guitars and Instruments', 'guitars-instruments','guitar'),
  ('Woodcarving',             'woodcarving',        'axe'),
  ('Pottery',                 'pottery',            'amphora'),
  ('Fashion and Accessories', 'fashion-accessories','gem'),
  ('Pasalubong and Delicacies','pasalubong',        'cookie')
on conflict (slug) do nothing;

insert into public.settings (key, value) values
  ('commission_percent', '5'),
  ('shipping_fee_per_shop', '50'),
  ('store', '{"name": "CRAFTCEBU", "email": "hello@craftcebu.test", "phone": ""}')
on conflict (key) do nothing;
