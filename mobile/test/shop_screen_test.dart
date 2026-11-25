import 'package:craftcebu_mobile/screens/shop/shop_screen.dart';
import 'package:craftcebu_mobile/web/bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

void main() {
  testWidgets('shows products from the repo', (tester) async {
    await pumpTall(tester, inShell(const ShopScreen(), services: fakeServices(), actions: FakeActions()));
    expect(find.text('Piece p1'), findsOneWidget);
    expect(find.text('Piece p2'), findsOneWidget);
  });

  testWidgets('quick add when signed out asks to sign in first', (tester) async {
    final session = FakeSession();
    final cart = FakeCart();
    final actions = FakeActions(session: session);
    await pumpTall(tester, inShell(const ShopScreen(), services: fakeServices(session: session, cart: cart), actions: actions));
    await tester.tap(find.byKey(const ValueKey('add-p1')));
    await tester.pumpAndSettle();
    expect(actions.log.first, 'requireSignIn');
    expect(cart.calls, ['add p1 1']);
  });

  testWidgets('second add at stock limit shows the limit message', (tester) async {
    final session = FakeSession(signedInAs: 'u1');
    final cart = FakeCart(addResults: [1, 1]);
    await pumpTall(tester, inShell(const ShopScreen(), services: fakeServices(session: session, cart: cart), actions: FakeActions(session: session)));
    await tester.tap(find.byKey(const ValueKey('add-p1')));
    await tester.pumpAndSettle();
    expect(find.text('Added Piece p1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('add-p1')));
    await tester.pumpAndSettle();
    expect(find.text('You already have every available piece in your cart.'), findsOneWidget);
  });

  testWidgets('empty results show clear filters', (tester) async {
    await pumpTall(tester, inShell(
      const ShopScreen(initialFilters: OpenShop(q: 'zzz')),
      services: fakeServices(catalog: FakeCatalog(products: [])),
      actions: FakeActions(),
    ));
    expect(find.text('Clear filters'), findsOneWidget);
  });

  testWidgets('a town name from the site selects that town', (tester) async {
    final catalog = FakeCatalog();
    await pumpTall(tester, inShell(const ShopScreen(initialFilters: OpenShop(town: 'Argao')), services: fakeServices(catalog: catalog), actions: FakeActions()));
    expect(catalog.filtersSeen.last.townId, 5);
  });
}
