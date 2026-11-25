import 'package:craftcebu_mobile/screens/product/product_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

void main() {
  testWidgets('shows name, price and maker', (tester) async {
    await pumpTall(tester, inShell(const ProductScreen(slug: 'piece-p1'), services: fakeServices(), actions: FakeActions()));
    expect(find.text('Piece p1'), findsWidgets);
    expect(find.text('₱500'), findsWidgets);
    expect(find.text('Lola Nena Pottery'), findsOneWidget);
  });

  testWidgets('stepper stops at remaining stock', (tester) async {
    final catalog = FakeCatalog(products: [fakeProduct('p1', stock: 2)]);
    await pumpTall(tester, inShell(const ProductScreen(slug: 'piece-p1'), services: fakeServices(catalog: catalog), actions: FakeActions()));
    final plus = find.byTooltip('More');
    await tester.tap(plus);
    await tester.pump();
    await tester.tap(plus);
    await tester.pump();
    expect(find.byKey(const ValueKey('qty')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const ValueKey('qty'))).data, '2');
    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.add)).onPressed, isNull);
  });

  testWidgets('sold out disables add to cart', (tester) async {
    final catalog = FakeCatalog(products: [fakeProduct('p1', stock: 0)]);
    await pumpTall(tester, inShell(const ProductScreen(slug: 'piece-p1'), services: fakeServices(catalog: catalog), actions: FakeActions()));
    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Sold out'));
    expect(button.onPressed, isNull);
  });

  testWidgets('missing product shows not available', (tester) async {
    await pumpTall(tester, inShell(const ProductScreen(slug: 'nope'), services: fakeServices(), actions: FakeActions()));
    expect(find.text("This piece isn't available"), findsOneWidget);
    expect(find.text('Back to shop'), findsOneWidget);
  });

  testWidgets('heart when signed out asks to sign in', (tester) async {
    final actions = FakeActions(session: FakeSession(), signInSucceeds: false);
    final wishlist = FakeWishlist();
    await pumpTall(tester, inShell(const ProductScreen(slug: 'piece-p1'), services: fakeServices(wishlist: wishlist), actions: actions));
    await tester.tap(find.byTooltip('Save'));
    await tester.pumpAndSettle();
    expect(actions.log, contains('requireSignIn'));
    expect(wishlist.saved, isEmpty);
  });

  testWidgets('add to cart sends the chosen quantity', (tester) async {
    final session = FakeSession(signedInAs: 'u1');
    final cart = FakeCart();
    await pumpTall(tester, inShell(const ProductScreen(slug: 'piece-p1'), services: fakeServices(session: session, cart: cart), actions: FakeActions(session: session)));
    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Add to cart'));
    await tester.pumpAndSettle();
    expect(cart.calls, ['add p1 2']);
  });
}
