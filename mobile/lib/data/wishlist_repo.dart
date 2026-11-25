import 'package:supabase_flutter/supabase_flutter.dart';

/// The signed-in shopper's saved pieces (the wishlists table).
class WishlistRepo {
  WishlistRepo([SupabaseClient? client]) : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Set<String>> savedIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};
    final rows = await _client.from('wishlists').select('product_id').eq('profile_id', user.id);
    return {for (final r in rows) r['product_id'] as String};
  }

  /// Saves or unsaves a piece; returns whether it is now saved.
  Future<bool> toggleSaved(String productId) async {
    final userId = _client.auth.currentUser!.id;
    final existing = await _client.from('wishlists').select('product_id').eq('profile_id', userId).eq('product_id', productId).maybeSingle();
    if (existing != null) {
      await _client.from('wishlists').delete().eq('profile_id', userId).eq('product_id', productId);
      return false;
    }
    await _client.from('wishlists').insert({'profile_id': userId, 'product_id': productId});
    return true;
  }
}
