import 'package:craftcebu_mobile/data/catalog_repo.dart';
import 'package:craftcebu_mobile/data/models.dart';
import 'package:craftcebu_mobile/data/stand_in_images.dart';
import 'package:flutter_test/flutter_test.dart';

// A row as catalog.ts's productSelect returns it.
Map<String, dynamic> row({List<Map<String, dynamic>> images = const [], String category = 'pottery'}) => {
      'id': 'p1',
      'artisan_id': 'a1',
      'name': 'Banga water jar',
      'slug': 'banga-water-jar',
      'description': 'Clay jar',
      'materials': 'Terracotta',
      'price': 850, // PostgREST sends whole numerics as ints
      'stock': 4,
      'is_active': true,
      'created_at': '2026-11-20T00:00:00Z',
      'artisan': {
        'id': 'a1',
        'shop_name': 'Lola Nena Pottery',
        'slug': 'lola-nena',
        'status': 'verified',
        'town_id': 4,
        'story': 'Three generations',
        'craft_since': 1978,
        'photo_url': null,
        'town': {'id': 4, 'name': 'Carcar City'},
      },
      'category': {'name': 'Pottery', 'slug': category},
      'images': images,
    };

void main() {
  test('parses a catalog row', () {
    final p = Product.fromJson(row());
    expect(p.name, 'Banga water jar');
    expect(p.price, 850.0);
    expect(p.price, isA<double>());
    expect(p.artisan.town?.name, 'Carcar City');
    expect(p.artisan.shopName, 'Lola Nena Pottery');
    expect(p.reviewCount, 0);
    expect(p.rating, isNull);
  });

  test('images sort by sort_order', () {
    final p = Product.fromJson(row(images: [
      {'url': 'b.jpg', 'sort_order': 2},
      {'url': 'a.jpg', 'sort_order': 0},
    ]));
    expect(p.images, ['a.jpg', 'b.jpg']);
    expect(p.coverImage, 'a.jpg');
  });

  test('product with no images uses the craft stand-in', () {
    expect(Product.fromJson(row()).coverImage, standInFor('pottery'));
    expect(standInFor('pottery'), contains('1468322638156-074863f9362e'));
    expect(standInFor('unknown'), contains('1777332546255-818d0cc8aff9'));
  });

  test('ratings attach to products', () {
    final p = Product.fromJson(row()).withRating(4.5, 2);
    expect(p.rating, 4.5);
    expect(p.reviewCount, 2);
  });

  test('search text drops PostgREST syntax characters', () {
    expect(cleanSearch('a,(b)*%'), 'a  b');
    expect(cleanSearch(r' hablon\ '), 'hablon');
  });
}
