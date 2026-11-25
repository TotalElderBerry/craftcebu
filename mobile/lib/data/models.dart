import 'stand_in_images.dart';

class TownRef {
  const TownRef({required this.id, required this.name});
  final int id;
  final String name;

  static TownRef? fromJson(Map<String, dynamic>? json) =>
      json == null ? null : TownRef(id: json['id'] as int, name: json['name'] as String);
}

class CategoryRef {
  const CategoryRef({this.id, required this.name, required this.slug});
  final int? id;
  final String name;
  final String slug;

  static CategoryRef? fromJson(Map<String, dynamic>? json) => json == null
      ? null
      : CategoryRef(id: json['id'] as int?, name: json['name'] as String, slug: json['slug'] as String);
}

class ArtisanSummary {
  const ArtisanSummary({
    required this.id,
    required this.shopName,
    required this.slug,
    this.photoUrl,
    this.story = '',
    this.craftSince,
    this.town,
  });

  final String id;
  final String shopName;
  final String slug;
  final String? photoUrl;
  final String story;
  final int? craftSince;
  final TownRef? town;

  factory ArtisanSummary.fromJson(Map<String, dynamic> json) => ArtisanSummary(
        id: json['id'] as String,
        shopName: json['shop_name'] as String,
        slug: json['slug'] as String,
        photoUrl: json['photo_url'] as String?,
        story: json['story'] as String? ?? '',
        craftSince: json['craft_since'] as int?,
        town: TownRef.fromJson(json['town'] as Map<String, dynamic>?),
      );
}

/// A product with its maker, town, category and photos, as on a product card.
class Product {
  const Product({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.materials,
    required this.price,
    required this.stock,
    required this.artisan,
    this.categoryId,
    this.category,
    this.images = const [],
    this.rating,
    this.reviewCount = 0,
  });

  final String id;
  final String name;
  final String slug;
  final String description;
  final String materials;
  final double price;
  final int stock;
  final ArtisanSummary artisan;
  final int? categoryId;
  final CategoryRef? category;

  /// Photo URLs in the shop's chosen order.
  final List<String> images;

  /// Average of visible reviews; null when there are none.
  final double? rating;
  final int reviewCount;

  String get coverImage => images.isNotEmpty ? images.first : standInFor(category?.slug);

  factory Product.fromJson(Map<String, dynamic> json) {
    final images = [...(json['images'] as List? ?? const []).cast<Map<String, dynamic>>()]
      ..sort((a, b) => (a['sort_order'] as int).compareTo(b['sort_order'] as int));
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String? ?? '',
      materials: json['materials'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      stock: json['stock'] as int,
      artisan: ArtisanSummary.fromJson(json['artisan'] as Map<String, dynamic>),
      categoryId: json['category_id'] as int?,
      category: CategoryRef.fromJson(json['category'] as Map<String, dynamic>?),
      images: [for (final image in images) image['url'] as String],
    );
  }

  Product withRating(double rating, int count) => Product(
        id: id,
        name: name,
        slug: slug,
        description: description,
        materials: materials,
        price: price,
        stock: stock,
        artisan: artisan,
        categoryId: categoryId,
        category: category,
        images: images,
        rating: rating,
        reviewCount: count,
      );
}

class Review {
  const Review({required this.id, required this.rating, required this.comment, required this.createdAt});
  final String id;
  final int rating;
  final String comment;
  final DateTime createdAt;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        rating: json['rating'] as int,
        comment: json['comment'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
