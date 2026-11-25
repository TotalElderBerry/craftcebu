import 'package:craftcebu_mobile/data/cart_repo.dart';
import 'package:craftcebu_mobile/shell/tab_shell.dart';
import 'package:craftcebu_mobile/theme.dart';
import 'package:craftcebu_mobile/web/bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'fakes.dart';

class FakeWebTab implements WebTabDriver {
  FakeWebTab({this.pushResult = true});

  bool pushResult;
  int pushes = 0;
  final paths = <String>[];
  String current = '/';
  int cartReloads = 0;

  @override
  Widget build(BuildContext context) => Text('web $current');
  @override
  Future<void> navigate(String path) async {
    paths.add(path);
    current = path;
  }

  @override
  Future<void> reloadCart() async => cartReloads++;
  @override
  Future<String?> currentPath() async => current;
  @override
  Future<bool> goBack() async => false;
  @override
  Future<bool> pushSession() async {
    pushes++;
    return pushResult;
  }

  @override
  void dispose() {}
}

late BridgeHandlers handlers;

Future<FakeWebTab> pumpShell(WidgetTester tester, {CartRepo? cart, FakeSession? session, FakeWebTab? webTab}) async {
  final web = webTab ?? FakeWebTab();
  await tester.pumpWidget(MaterialApp(
    theme: craftCebuTheme(),
    home: TabShell(
      services: fakeServices(cart: cart, session: session),
      webTabFactory: (h) {
        handlers = h;
        return web;
      },
    ),
  ));
  await tester.pump();
  return web;
}

void main() {
  testWidgets('tapping Shop shows the shop screen', (tester) async {
    await pumpShell(tester);
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop-screen')), findsOneWidget);
  });

  testWidgets('cart badge shows the piece count', (tester) async {
    await pumpShell(tester, cart: FakeCart(count: 3));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Badge), matching: find.text('3')), findsOneWidget);
  });

  testWidgets('switching web tabs opens their page and reloads the cart', (tester) async {
    final web = await pumpShell(tester);
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    expect(web.paths, ['/cart', '/orders']);
    expect(web.cartReloads, 1);
  });

  testWidgets('a web tab returns to where it was left', (tester) async {
    final web = await pumpShell(tester);
    await web.navigate('/artisans/lola');
    web.paths.clear();
    await tester.tap(find.text('Cart'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(web.paths, ['/cart', '/artisans/lola']);
  });

  testWidgets('signing out takes web tabs back to their public pages', (tester) async {
    final session = FakeSession(signedInAs: 'u1');
    final web = await pumpShell(tester, session: session);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await web.navigate('/orders/abc');
    web.paths.clear();
    await session.signOut();
    await tester.pumpAndSettle();
    expect(web.paths, ['/']);
    await tester.tap(find.text('Orders'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(web.paths, isNot(contains('/orders/abc')));
  });

  testWidgets('a sign-in request while signed in lends the session, then opens the page once', (tester) async {
    final web = await pumpShell(tester, session: FakeSession(signedInAs: 'u1'));
    handlers.onLogin('/orders');
    handlers.onLogin('/orders');
    await tester.pumpAndSettle();
    expect(web.pushes, 1);
    expect(web.paths, ['/orders']);
  });

  testWidgets('no page loop when the session could not be lent', (tester) async {
    final web = await pumpShell(tester, session: FakeSession(signedInAs: 'u1'), webTab: FakeWebTab(pushResult: false));
    handlers.onLogin('/orders');
    await tester.pumpAndSettle();
    expect(web.paths, isEmpty);
  });
}
