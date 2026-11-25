import 'package:material_ui/material_ui.dart';

import '../data/cart_repo.dart';
import '../data/catalog_repo.dart';
import '../data/wishlist_repo.dart';
import '../session/app_session.dart';

/// Everything the native screens talk to, passed down so tests can swap in
/// fakes.
class AppServices {
  AppServices({required this.session, required this.cart, required this.catalog, required this.wishlist});

  final AppSession session;
  final CartRepo cart;
  final CatalogRepo catalog;
  final WishlistRepo wishlist;

  /// Pieces in the cart, shown on the Cart tab.
  final cartCount = ValueNotifier<int>(0);

  /// The quantity add_to_cart last returned for each product, so a tap that
  /// can't add more (stock reached) can say so.
  final lastCartQty = <String, int>{};

  Future<void> refreshCartCount() async {
    try {
      cartCount.value = await cart.pieceCount();
    } catch (_) {
      // Keep the last count when offline.
    }
  }
}
