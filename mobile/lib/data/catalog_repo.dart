import 'package:supabase_flutter/supabase_flutter.dart';

import 'models.dart';

enum SortKey { newest, priceAsc, priceDesc }

class CatalogFilters {
  const CatalogFilters({this.q, this.category, this.townId, this.minPrice, this.maxPrice, this.artisanId, this.sort = SortKey.newest});

  final String? q;
  final String? category; // category slug
  final int? townId;
  final double? minPrice;
  final double? maxPrice;
  final String? artisanId;
  final SortKey sort;

  bool get isFiltered => (q?.isNotEmpty ?? false) || category != null || townId != null || minPrice != null || maxPrice != null;
}

// PostgREST's or() filter uses commas and parentheses as syntax.
String cleanSearch(String q) => q.replaceAll(RegExp(r'[,()*%\\]'), ' ').trim();

// Same select as src/lib/catalog.ts. Inner joins keep only products whose
// artisan is verified (and, when filtering, whose category matches); RLS
// enforces the same rule.
const _productSelect = '''
  *,
  artisan:artisans!inner(id, shop_name, slug, status, town_id, story, craft_since, photo_url, town:towns(id, name)),
  category:categories(name, slug),
  images:product_images(url, sort_order)
''';
final _productSelectByCategory = _productSelect.replaceFirst('category:categories(', 'category:categories!inner(');
const _artisanSelect = 'id, shop_name, slug, story, craft_since, photo_url, town:towns(id, name)';

/// The public catalog, mirroring the queries in src/lib/catalog.ts.
class CatalogRepo {
  CatalogRepo([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  PostgrestFilterBuilder<List<Map<String, dynamic>>> _visible(String select) =>
      _client.from('products').select(select).eq('is_active', true).eq('artisan.status', 'verified');

  Future<({List<Product> products, int total})> fetchProducts(CatalogFilters f, {int page = 0, int pageSize = 12}) async {
    var query = _visible(f.category != null ? _productSelectByCategory : _productSelect);
    final q = f.q == null ? '' : cleanSearch(f.q!);
    if (q.isNotEmpty) query = query.or('name.ilike.%$q%,description.ilike.%$q%,materials.ilike.%$q%');
    if (f.category != null) query = query.eq('category.slug', f.category!);
    if (f.townId != null) query = query.eq('artisan.town_id', f.townId!);
    if (f.artisanId != null) query = query.eq('artisan_id', f.artisanId!);
    if (f.minPrice != null) query = query.gte('price', f.minPrice!);
    if (f.maxPrice != null) query = query.lte('price', f.maxPrice!);

    final ordered = switch (f.sort) {
      SortKey.priceAsc => query.order('price', ascending: true),
      SortKey.priceDesc => query.order('price', ascending: false),
      SortKey.newest => query.order('created_at', ascending: false),
    };
    final from = page * pageSize;
    final res = await ordered.range(from, from + pageSize - 1).count(CountOption.exact);
    return (products: await _withRatings(res.data.map(Product.fromJson).toList()), total: res.count);
  }

  Future<({List<TownRef> towns, List<CategoryRef> categories})> fetchFacets() async {
    final towns = await _client.from('towns').select('id, name').order('name');
    final categories = await _client.from('categories').select('id, name, slug').order('id');
    return (
      towns: [for (final t in towns) TownRef.fromJson(t)!],
      categories: [for (final c in categories) CategoryRef.fromJson(c)!],
    );
  }

  Future<Product?> fetchProduct(String slug) async {
    final row = await _visible(_productSelect).eq('slug', slug).maybeSingle();
    if (row == null) return null;
    return (await _withRatings([Product.fromJson(row)])).first;
  }

  Future<List<Review>> fetchReviews(String productId) async {
    final rows = await _client
        .from('reviews')
        .select('id, rating, comment, created_at')
        .eq('product_id', productId)
        .eq('is_hidden', false)
        .order('created_at', ascending: false);
    return rows.map(Review.fromJson).toList();
  }

  Future<List<ArtisanSummary>> fetchMakers() async {
    final rows = await _client.from('artisans').select(_artisanSelect).eq('status', 'verified').order('shop_name');
    return rows.map(ArtisanSummary.fromJson).toList();
  }

  /// Pieces in the same craft from other shops (as on the site).
  Future<List<Product>> fetchRelated(Product p) async {
    if (p.categoryId == null) return [];
    final rows = await _visible(_productSelect).eq('category_id', p.categoryId!).neq('artisan_id', p.artisan.id).order('created_at', ascending: false).limit(8);
    return _withRatings(rows.map(Product.fromJson).toList());
  }

  /// Other pieces from the same shop.
  Future<List<Product>> fetchFromMaker(Product p) async {
    final rows = await _visible(_productSelect).eq('artisan_id', p.artisan.id).neq('id', p.id).order('created_at', ascending: false).limit(8);
    return _withRatings(rows.map(Product.fromJson).toList());
  }

  // Average star rating of visible reviews, added in one query.
  Future<List<Product>> _withRatings(List<Product> products) async {
    if (products.isEmpty) return products;
    final rows = await _client.from('reviews').select('product_id, rating').inFilter('product_id', [for (final p in products) p.id]).eq('is_hidden', false);
    final totals = <String, (int sum, int n)>{};
    for (final r in rows) {
      final (sum, n) = totals[r['product_id']] ?? (0, 0);
      totals[r['product_id'] as String] = (sum + (r['rating'] as int), n + 1);
    }
    return [
      for (final p in products)
        if (totals[p.id] case (final sum, final n)) p.withRating(sum / n, n) else p,
    ];
  }
}
