import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../shell/tab_shell.dart';
import '../../theme.dart';
import '../add_to_cart.dart';
import '../common.dart';
import '../shop/product_card.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String _date(DateTime d) => '${_months[d.month - 1]} ${d.day}, ${d.year}';

/// The native product page, mirroring src/views/ProductView.vue.
class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.slug});

  final String slug;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  final _reviewsKey = GlobalKey();
  final _pages = PageController();

  bool _loading = true;
  Product? _product;
  List<Review> _reviews = [];
  List<Product> _fromMaker = [];
  List<Product> _related = [];
  bool _saved = false;
  int _image = 0;
  int _qty = 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final services = TabShellScope.of(context).services;
    try {
      final product = await services.catalog.fetchProduct(widget.slug);
      if (!mounted) return;
      setState(() {
        _product = product;
        _loading = false;
      });
      if (product == null) return;
      final results = await Future.wait([
        services.catalog.fetchReviews(product.id),
        services.catalog.fetchFromMaker(product),
        services.catalog.fetchRelated(product),
        if (services.session.signedIn) services.wishlist.savedIds(),
      ]);
      if (!mounted) return;
      setState(() {
        _reviews = results[0] as List<Review>;
        _fromMaker = results[1] as List<Product>;
        _related = results[2] as List<Product>;
        if (results.length > 3) _saved = (results[3] as Set<String>).contains(product.id);
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      if (mounted && _product != null) showMessage(context, 'Some details could not load.');
    }
  }

  /// Pieces left to add: the stock, less what this app last put in the cart.
  int get _room {
    final p = _product!;
    final inCart = TabShellScope.of(context).services.lastCartQty[p.id] ?? 0;
    return math.max(1, p.stock - inCart);
  }

  Future<void> _toggleSaved() async {
    final scope = TabShellScope.of(context);
    if (!scope.services.session.signedIn && !await scope.actions.requireSignIn()) return;
    try {
      final saved = await scope.services.wishlist.toggleSaved(_product!.id);
      if (!mounted) return;
      setState(() => _saved = saved);
      showMessage(context, saved ? 'Saved ${_product!.name}' : 'Removed from your saved pieces');
    } catch (_) {
      if (mounted) showMessage(context, 'Could not update your saved pieces.');
    }
  }

  void _openMaker() {
    final actions = TabShellScope.of(context).actions;
    Navigator.of(context).maybePop();
    actions.showWebPath('/artisans/${_product!.artisan.slug}');
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: atsuete)),
      );
    }
    final p = _product;
    if (p == null) {
      return _NotAvailable(
        onBack: () {
          final actions = TabShellScope.of(context).actions;
          Navigator.of(context).maybePop();
          actions.switchTo(AppTab.shop);
        },
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // One column, so the sheet paints over the photo's bottom edge
          // (a scroll view paints earlier slivers on top).
          SliverToBoxAdapter(
            child: Column(
              children: [
                _gallery(p),
                Transform.translate(
                  offset: const Offset(0, -24),
                  // Material, not a coloured box, so the details' ink shows.
                  child: Material(
                    color: paper,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _summary(p),
                          const SizedBox(height: 20),
                          _MakerCard(artisan: p.artisan, onTap: _openMaker),
                          const SizedBox(height: 16),
                          _Highlights(town: p.artisan.town?.name ?? 'Cebu'),
                          const SizedBox(height: 16),
                          _Details(product: p),
                          const SizedBox(height: 28),
                          _ReviewsSection(key: _reviewsKey, reviews: _reviews),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_fromMaker.isNotEmpty)
            SliverToBoxAdapter(
              child: _Rail(title: 'More from ${p.artisan.shopName}', products: _fromMaker),
            ),
          if (_related.isNotEmpty)
            SliverToBoxAdapter(
              child: _Rail(title: 'You may also like', products: _related),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
      bottomNavigationBar: _buyBar(p),
    );
  }

  Widget _gallery(Product p) {
    final images = p.images.isEmpty ? [p.coverImage] : p.images;
    final width = MediaQuery.sizeOf(context).width;
    Widget circleButton(IconData icon, String tooltip, VoidCallback onTap, {Color color = ink}) => Material(
      color: paper.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        icon: Icon(icon, color: color),
        onPressed: onTap,
      ),
    );
    return SizedBox(
      height: width * 1.1,
      child: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _image = i),
            itemBuilder: (_, i) => NetImage(images[i]),
          ),
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 36,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _image ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(color: i == _image ? Colors.white : Colors.white54, borderRadius: BorderRadius.circular(3)),
                    ),
                ],
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  circleButton(Icons.arrow_back, 'Back', () => Navigator.of(context).maybePop()),
                  const Spacer(),
                  circleButton(
                    _saved ? Icons.favorite : Icons.favorite_border,
                    _saved ? 'Saved' : 'Save',
                    _toggleSaved,
                    color: _saved ? atsuete : ink,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summary(Product p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (p.category != null) Caps(p.category!.name),
        const SizedBox(height: 6),
        Text(p.name, style: display(28)),
        const SizedBox(height: 8),
        Text(peso(p.price), style: display(26, weight: 600, color: atsuete)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (p.artisan.town != null)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place, size: 16, color: atsuete),
                  const SizedBox(width: 3),
                  Text(p.artisan.town!.name, style: body(14, color: muted)),
                ],
              ),
            if (p.rating != null)
              GestureDetector(
                onTap: () => Scrollable.ensureVisible(_reviewsKey.currentContext!, duration: const Duration(milliseconds: 400)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, size: 18, color: mango),
                    const SizedBox(width: 3),
                    Text(
                      '${p.rating!.toStringAsFixed(1)} · ${p.reviewCount} ${p.reviewCount == 1 ? 'review' : 'reviews'}',
                      style: body(14, color: muted).copyWith(decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            Text(
              p.stock == 0
                  ? 'Sold out'
                  : p.stock <= 3
                  ? 'Only ${p.stock} left'
                  : 'In stock',
              style: body(
                14,
                weight: 600,
                color: p.stock == 0
                    ? muted
                    : p.stock <= 3
                    ? atsuete
                    : const Color(0xFF2F7D4E),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buyBar(Product p) {
    final soldOut = p.stock == 0;
    final room = soldOut ? 1 : _room;
    final qty = math.min(_qty, room);
    return Container(
      decoration: const BoxDecoration(
        color: card,
        border: Border(top: BorderSide(color: line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              if (!soldOut) ...[
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Fewer',
                        icon: const Icon(Icons.remove),
                        onPressed: qty > 1 ? () => setState(() => _qty = qty - 1) : null,
                      ),
                      Text('$qty', key: const ValueKey('qty'), style: body(16, weight: 600)),
                      IconButton(
                        tooltip: 'More',
                        icon: const Icon(Icons.add),
                        onPressed: qty < room ? () => setState(() => _qty = qty + 1) : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total', style: body(12, color: muted)),
                    Text(peso(p.price * qty), style: display(18, weight: 600)),
                  ],
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: FilledButton(
                  onPressed: soldOut ? null : () => addToCart(context, p, qty),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), textStyle: body(16, weight: 600)),
                  child: Text(soldOut ? 'Sold out' : 'Add to cart'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotAvailable extends StatelessWidget {
  const _NotAvailable({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: paper),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("This piece isn't available", textAlign: TextAlign.center, style: display(24)),
              const SizedBox(height: 8),
              Text(
                'It may have sold out or been taken down by its maker.',
                textAlign: TextAlign.center,
                style: body(14, color: muted),
              ),
              const SizedBox(height: 20),
              OutlinedButton(onPressed: onBack, child: const Text('Back to shop')),
            ],
          ),
        ),
      ),
    );
  }
}

class _MakerCard extends StatelessWidget {
  const _MakerCard({required this.artisan, required this.onTap});
  final ArtisanSummary artisan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final years = yearsInCraft(artisan.craftSince);
    return Material(
      color: card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: line),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 52,
                  child: artisan.photoUrl == null
                      ? const ColoredBox(
                          color: line,
                          child: Icon(Icons.storefront, color: atsuete),
                        )
                      : NetImage(artisan.photoUrl!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Made by', style: body(12, color: muted)),
                    Row(
                      children: [
                        Flexible(
                          child: Text(artisan.shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(18)),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 16, color: atsuete),
                      ],
                    ),
                    if (years != null) Text('$years ${years == 1 ? 'year' : 'years'} in the craft', style: body(12.5, color: muted)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _Highlights extends StatelessWidget {
  const _Highlights({required this.town});
  final String town;

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData icon, String top, String bottom) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(color: line.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, size: 20, color: atsuete),
            const SizedBox(height: 6),
            Text(top, style: body(12, weight: 500)),
            Text(
              bottom,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: body(12, color: muted),
            ),
          ],
        ),
      ),
    );
    return Row(
      children: [
        tile(Icons.back_hand_outlined, 'Handmade', 'in $town'),
        const SizedBox(width: 8),
        tile(Icons.local_shipping_outlined, 'Ships from', 'the maker'),
        const SizedBox(width: 8),
        tile(Icons.payments_outlined, 'Maya or', 'cash on delivery'),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    Widget section(String title, String text, {bool open = false}) => Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: open,
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 14),
        expandedAlignment: Alignment.centerLeft,
        title: Text(title, style: body(16, weight: 600)),
        children: [Text(text, style: body(15, color: const Color(0xFF3D3631), height: 1.55))],
      ),
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: line),
          bottom: BorderSide(color: line),
        ),
      ),
      child: Column(
        children: [
          if (product.description.isNotEmpty) section('About this piece', product.description, open: true),
          if (product.materials.isNotEmpty) ...[const Divider(height: 1, color: line), section('Materials', product.materials)],
        ],
      ),
    );
  }
}

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({super.key, required this.reviews});
  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final count = reviews.length;
    final average = count == 0 ? 0.0 : reviews.fold<int>(0, (s, r) => s + r.rating) / count;
    Widget stars(double value, {double size = 16}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++) Icon(i <= value.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: mango),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Reviews', style: display(26)),
        const SizedBox(height: 12),
        if (count == 0)
          Text('No reviews yet. Buyers can review a piece once it is delivered.', style: body(14, color: muted))
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(average.toStringAsFixed(1), style: display(40, weight: 600)),
                  stars(average),
                  const SizedBox(height: 2),
                  Text('$count ${count == 1 ? 'review' : 'reviews'}', style: body(12, color: muted)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    for (var star = 5; star >= 1; star--)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 14,
                              child: Text('$star', style: body(12, color: muted)),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: reviews.where((r) => r.rating == star).length / count,
                                  minHeight: 7,
                                  color: mango,
                                  backgroundColor: line,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final r in reviews)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  stars(r.rating.toDouble(), size: 15),
                  if (r.comment.isNotEmpty) ...[const SizedBox(height: 6), Text(r.comment, style: body(14.5, height: 1.5))],
                  const SizedBox(height: 8),
                  Text('Verified buyer · ${_date(r.createdAt)}', style: body(12, color: muted)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Rail extends StatelessWidget {
  const _Rail({required this.title, required this.products});
  final String title;
  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    final actions = TabShellScope.of(context).actions;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(title, style: display(22)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 330,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: products.length,
              separatorBuilder: (_, _) => const SizedBox(width: 14),
              itemBuilder: (context, i) => SizedBox(
                width: 160,
                child: ProductCard(
                  product: products[i],
                  onTap: () => actions.openProduct(products[i].slug),
                  onQuickAdd: () => addToCart(context, products[i], 1),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
