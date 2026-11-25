import 'package:supabase_flutter/supabase_flutter.dart';

/// Why add_to_cart refused: 'sold_out' or 'not_available'.
class CartException implements Exception {
  const CartException(this.kind);
  final String kind;

  String get message => kind == 'sold_out' ? 'This piece is sold out.' : 'This piece is no longer available.';
}

/// The signed-in shopper's cart in Supabase, shared with the site's Cart tab.
class CartRepo {
  CartRepo([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Returns the new quantity; the database never lets it pass the stock.
  Future<int> addToCart(String productId, int qty) async {
    try {
      return await _client.rpc<int>('add_to_cart', params: {'p_product_id': productId, 'p_qty': qty});
    } on PostgrestException catch (e) {
      for (final kind in const ['sold_out', 'not_available']) {
        if (e.message.contains(kind)) throw CartException(kind);
      }
      rethrow;
    }
  }

  /// Pieces the shopper can still buy, for the tab badge. Zero when signed out.
  Future<int> pieceCount() async {
    if (_client.auth.currentUser == null) return 0;
    final rows = await _client.from('cart_items').select('qty, product:products(stock, is_active, artisan:artisans(status))');
    var total = 0;
    for (final row in rows) {
      final product = row['product'] as Map<String, dynamic>?;
      final artisan = product?['artisan'] as Map<String, dynamic>?;
      if (product?['is_active'] == true && artisan?['status'] == 'verified' && (product?['stock'] as int? ?? 0) > 0) {
        total += row['qty'] as int;
      }
    }
    return total;
  }
}
