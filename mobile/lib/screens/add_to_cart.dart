import 'package:material_ui/material_ui.dart';

import '../data/cart_repo.dart';
import '../data/models.dart';
import '../shell/tab_shell.dart';
import 'common.dart';

/// Adds pieces to the cart the same way from every screen: sign in first if
/// needed, then add, then say what happened.
Future<void> addToCart(BuildContext context, Product product, int qty) async {
  final scope = TabShellScope.of(context);
  final services = scope.services;
  if (!services.session.signedIn && !await scope.actions.requireSignIn()) return;
  if (!context.mounted) return;

  final int newQty;
  try {
    newQty = await services.cart.addToCart(product.id, qty);
  } on CartException catch (e) {
    if (context.mounted) showMessage(context, e.message);
    return;
  } catch (_) {
    if (context.mounted) showMessage(context, 'Could not add to your cart. Please try again.');
    return;
  }
  final before = services.lastCartQty[product.id];
  services.lastCartQty[product.id] = newQty;
  await services.refreshCartCount();
  if (!context.mounted) return;

  // The database stops at the stock, so no growth means the shopper already
  // has every piece there is.
  if (before == newQty) {
    showMessage(context, 'You already have every available piece in your cart.');
    return;
  }
  showMessage(
    context,
    'Added ${product.name}',
    action: SnackBarAction(label: 'View cart', onPressed: () => scope.actions.switchTo(AppTab.cart)),
  );
}
