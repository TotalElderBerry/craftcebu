import 'package:craftcebu_mobile/data/cart_repo.dart';
import 'package:craftcebu_mobile/data/catalog_repo.dart';
import 'package:craftcebu_mobile/data/models.dart';
import 'package:craftcebu_mobile/data/wishlist_repo.dart';
import 'package:craftcebu_mobile/session/app_session.dart';
import 'package:craftcebu_mobile/shell/services.dart';
import 'package:craftcebu_mobile/shell/tab_shell.dart';
import 'package:craftcebu_mobile/theme.dart';
import 'package:craftcebu_mobile/web/bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeSession extends ChangeNotifier implements AppSession {
  FakeSession({this.signedInAs, this.profile, this.signInError});

  String? signedInAs;
  @override
  Profile? profile;
  Object? signInError;
  final calls = <String>[];

  @override
  User? get user => signedInAs == null
      ? null
      : User(id: signedInAs!, appMetadata: const {}, userMetadata: const {}, aud: 'authenticated', createdAt: '', email: '$signedInAs@test.local');
  @override
  bool get signedIn => signedInAs != null;

  @override
  Future<void> signIn(String email, String password) async {
    calls.add('signIn');
    if (signInError != null) throw signInError!;
    signedInAs = 'u1';
    notifyListeners();
  }

  @override
  Future<bool> signUp(String fullName, String email, String password) async {
    calls.add('signUp');
    return true;
  }

  @override
  Future<void> sendPasswordReset(String email) async => calls.add('reset');

  @override
  Future<void> signOut() async {
    calls.add('signOut');
    signedInAs = null;
    profile = null;
    notifyListeners();
  }

  @override
  Future<Map<String, Object?>?> webSessionPayload() async => null;
}

class FakeCart implements CartRepo {
  FakeCart({this.count = 0, List<int>? addResults}) : addResults = addResults ?? [];

  int count;
  final List<int> addResults;
  final calls = <String>[];

  @override
  Future<int> addToCart(String productId, int qty) async {
    calls.add('add $productId $qty');
    return addResults.isEmpty ? qty : addResults.removeAt(0);
  }

  @override
  Future<int> pieceCount() async => count;
}

Product fakeProduct(String id, {int stock = 5, double price = 500, String? category = 'pottery', int? categoryId = 6}) => Product(
      id: id,
      name: 'Piece $id',
      slug: 'piece-$id',
      description: 'Made by hand.',
      materials: 'Clay',
      price: price,
      stock: stock,
      categoryId: categoryId,
      category: category == null ? null : CategoryRef(name: 'Pottery', slug: category),
      artisan: const ArtisanSummary(id: 'a1', shopName: 'Lola Nena Pottery', slug: 'lola-nena', town: TownRef(id: 4, name: 'Carcar City')),
    );

class FakeCatalog implements CatalogRepo {
  FakeCatalog({List<Product>? products, this.reviews = const []}) : products = products ?? [fakeProduct('p1'), fakeProduct('p2')];

  List<Product> products;
  List<Review> reviews;
  final filtersSeen = <CatalogFilters>[];

  @override
  Future<({List<Product> products, int total})> fetchProducts(CatalogFilters f, {int page = 0, int pageSize = 12}) async {
    filtersSeen.add(f);
    final pageItems = products.skip(page * pageSize).take(pageSize).toList();
    return (products: pageItems, total: products.length);
  }

  @override
  Future<({List<TownRef> towns, List<CategoryRef> categories})> fetchFacets() async => (
        towns: const [TownRef(id: 4, name: 'Carcar City'), TownRef(id: 5, name: 'Argao')],
        categories: const [CategoryRef(id: 6, name: 'Pottery', slug: 'pottery'), CategoryRef(id: 1, name: 'Hablon Weaving', slug: 'hablon-weaving')],
      );

  @override
  Future<Product?> fetchProduct(String slug) async => products.where((p) => p.slug == slug).firstOrNull;

  @override
  Future<List<Review>> fetchReviews(String productId) async => reviews;

  @override
  Future<List<ArtisanSummary>> fetchMakers() async => [products.first.artisan];

  @override
  Future<List<Product>> fetchRelated(Product p) async => [];

  @override
  Future<List<Product>> fetchFromMaker(Product p) async => [];
}

class FakeWishlist implements WishlistRepo {
  final saved = <String>{};

  @override
  Future<Set<String>> savedIds() async => {...saved};

  @override
  Future<bool> toggleSaved(String productId) async => saved.remove(productId) ? false : saved.add(productId);
}

AppServices fakeServices({AppSession? session, CartRepo? cart, CatalogRepo? catalog, WishlistRepo? wishlist}) => AppServices(
      session: session ?? FakeSession(),
      cart: cart ?? FakeCart(),
      catalog: catalog ?? FakeCatalog(),
      wishlist: wishlist ?? FakeWishlist(),
    );

/// Records what a screen asked the shell to do, in order, in [log].
class FakeActions implements ShellActions {
  FakeActions({this.session, this.signInSucceeds = true});

  final FakeSession? session;
  final bool signInSucceeds;
  final log = <String>[];

  @override
  void switchTo(AppTab tab) => log.add('switchTo ${tab.name}');
  @override
  void openShop(OpenShop filters) => log.add('openShop');
  @override
  Future<void> openProduct(String slug) async => log.add('openProduct $slug');
  @override
  void showWebPath(String path) => log.add('showWebPath $path');
  @override
  Future<bool> requireSignIn() async {
    log.add('requireSignIn');
    if (session?.signedIn ?? false) return true;
    if (signInSucceeds) session?.signedInAs = 'u1';
    return signInSucceeds;
  }

  @override
  void openWebPage(String path) => log.add('openWebPage $path');
}

/// Puts a native screen inside the shell's scope, with fakes.
Widget inShell(Widget child, {required AppServices services, required ShellActions actions}) => MaterialApp(
      theme: craftCebuTheme(),
      home: TabShellScope(actions: actions, services: services, child: Scaffold(body: child)),
    );

/// A phone-sized but tall screen, so lazily built grids show every card.
Future<void> pumpTall(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(400, 2400));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}
