import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../screens/account/account_screen.dart';
import '../screens/account/sign_in_screen.dart';
import '../screens/product/product_screen.dart';
import '../screens/shop/shop_screen.dart';
import '../screens/web_page_screen.dart';
import '../theme.dart';
import '../web/bridge.dart';
import 'live_web_tab.dart';
import 'services.dart';

enum AppTab { home, shop, cart, orders, account }

/// The site's pages for the web tabs.
const _webRoots = {AppTab.home: '/', AppTab.cart: '/cart', AppTab.orders: '/orders'};

/// The one web view shared by the Home, Cart and Orders tabs.
abstract interface class WebTabDriver {
  Widget build(BuildContext context);
  Future<void> navigate(String path);
  Future<void> reloadCart();
  Future<String?> currentPath();

  /// Steps back a page; false when there is nothing to go back to.
  Future<bool> goBack();
  void dispose();
}

/// What native screens can ask the shell to do.
abstract interface class ShellActions {
  void switchTo(AppTab tab);
  void openShop(OpenShop filters);
  Future<void> openProduct(String slug);

  /// Shows a site page in the web tab it belongs to (/cart, /orders, else Home).
  void showWebPath(String path);

  /// Resolves true once the shopper is signed in.
  Future<bool> requireSignIn();
  void openWebPage(String path);
}

class TabShellScope extends InheritedWidget {
  const TabShellScope({super.key, required this.actions, required this.services, required super.child});

  final ShellActions actions;
  final AppServices services;

  static TabShellScope of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<TabShellScope>()!;

  @override
  bool updateShouldNotify(TabShellScope oldWidget) => actions != oldWidget.actions || services != oldWidget.services;
}

class TabShell extends StatefulWidget {
  const TabShell({super.key, required this.services, this.webTabFactory});

  final AppServices services;

  /// Makes the shared web view; tests pass a fake.
  final WebTabDriver Function(BridgeHandlers handlers)? webTabFactory;

  @override
  State<TabShell> createState() => _TabShellState();
}

class _TabShellState extends State<TabShell> implements ShellActions {
  late final WebTabDriver _web;
  final _shopKey = GlobalKey<ShopScreenState>();
  AppTab _tab = AppTab.home;

  // Which web tab the web view is showing, and where each one was left.
  AppTab _webShowing = AppTab.home;
  final _lastPath = <AppTab, String>{};

  AppServices get _services => widget.services;

  @override
  void initState() {
    super.initState();
    final handlers = BridgeHandlers(
      onLogin: _onLoginRequest,
      onOpenProduct: openProduct,
      onOpenShop: openShop,
      onCartChanged: _services.refreshCartCount,
    );
    _web = widget.webTabFactory?.call(handlers) ?? LiveWebTab(_services.session, handlers);
    _services.session.addListener(_services.refreshCartCount);
    _services.refreshCartCount();
  }

  @override
  void dispose() {
    _services.session.removeListener(_services.refreshCartCount);
    _web.dispose();
    super.dispose();
  }

  @override
  void switchTo(AppTab tab) {
    final reselect = tab == _tab;
    setState(() => _tab = tab);
    final root = _webRoots[tab];
    if (root == null) return;
    unawaited(_showWebTab(tab, reselect ? root : null));
  }

  // Points the web view at a web tab's page: the given path, else where that
  // tab was left, else its root.
  Future<void> _showWebTab(AppTab tab, String? path) async {
    if (tab == AppTab.cart) unawaited(_web.reloadCart());
    if (path == null && tab == _webShowing) return;
    if (tab != _webShowing) {
      final left = await _web.currentPath();
      if (left != null) _lastPath[_webShowing] = left;
      _webShowing = tab;
    }
    await _web.navigate(path ?? _lastPath[tab] ?? _webRoots[tab]!);
  }

  @override
  void showWebPath(String path) {
    final tab = path.startsWith('/cart')
        ? AppTab.cart
        : path.startsWith('/orders')
            ? AppTab.orders
            : AppTab.home;
    setState(() => _tab = tab);
    unawaited(_showWebTab(tab, path));
  }

  @override
  void openShop(OpenShop filters) {
    switchTo(AppTab.shop);
    _shopKey.currentState?.applyFilters(filters);
  }

  // Pushed routes sit above the shell in the navigator, so they get the
  // shell's scope passed along.
  Future<T?> _push<T>(Widget screen) => Navigator.of(context).push(MaterialPageRoute<T>(
        builder: (_) => TabShellScope(actions: this, services: _services, child: screen),
      ));

  @override
  Future<void> openProduct(String slug) => _push<void>(ProductScreen(slug: slug));

  @override
  Future<bool> requireSignIn() async {
    if (_services.session.signedIn) return true;
    final signedIn = await _push<bool>(const SignInScreen());
    return signedIn == true && _services.session.signedIn;
  }

  @override
  void openWebPage(String path) => unawaited(_push<void>(WebPageScreen(path: path)));

  Future<void> _onLoginRequest(String returnTo) async {
    if (await requireSignIn()) showWebPath(returnTo);
  }

  // Android back: step back in the web view, then go Home, then leave.
  Future<void> _handleBack() async {
    if (_webRoots.containsKey(_tab) && await _web.goBack()) return;
    if (_tab != AppTab.home) {
      switchTo(AppTab.home);
      return;
    }
    await SystemNavigator.pop();
  }

  int get _stackIndex => switch (_tab) {
        AppTab.shop => 1,
        AppTab.account => 2,
        _ => 0,
      };

  @override
  Widget build(BuildContext context) {
    return TabShellScope(
      actions: this,
      services: _services,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: paper,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: card,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _handleBack();
          },
          child: Scaffold(
            body: IndexedStack(
              index: _stackIndex,
              children: [
                SafeArea(bottom: false, child: _web.build(context)),
                KeyedSubtree(key: const ValueKey('shop-screen'), child: ShopScreen(key: _shopKey)),
                const AccountScreen(key: ValueKey('account-screen')),
              ],
            ),
            bottomNavigationBar: ValueListenableBuilder(
              valueListenable: _services.cartCount,
              builder: (context, count, _) => NavigationBar(
                selectedIndex: _tab.index,
                onDestinationSelected: (i) => switchTo(AppTab.values[i]),
                destinations: [
                  const NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
                  const NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'Shop'),
                  NavigationDestination(
                    icon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_bag_outlined)),
                    selectedIcon: Badge(isLabelVisible: count > 0, label: Text('$count'), child: const Icon(Icons.shopping_bag)),
                    label: 'Cart',
                  ),
                  const NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'Orders'),
                  const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
