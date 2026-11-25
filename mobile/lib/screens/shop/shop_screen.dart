import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../data/catalog_repo.dart';
import '../../data/models.dart';
import '../../data/stand_in_images.dart';
import '../../shell/tab_shell.dart';
import '../../theme.dart';
import '../../web/bridge.dart';
import '../add_to_cart.dart';
import '../common.dart';
import 'filter_sheet.dart';
import 'product_card.dart';

const _pageSize = 12;

/// The native catalog, mirroring the site's Shop page (src/views/ShopView.vue).
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key, this.initialFilters});

  final OpenShop? initialFilters;

  @override
  State<ShopScreen> createState() => ShopScreenState();
}

class ShopScreenState extends State<ShopScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _searchTimer;

  List<TownRef> _towns = [];
  List<CategoryRef> _categories = [];
  List<ArtisanSummary> _makers = [];
  bool _facetsLoaded = false;

  String? _category;
  String? _townName;
  double? _min;
  double? _max;
  SortKey _sort = SortKey.newest;

  List<Product> _products = [];
  int _total = 0;
  int _page = 0;
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    final f = widget.initialFilters;
    if (f != null) _take(f);
    _search.addListener(_onSearchChanged);
    _scroll.addListener(_onScroll);
    // After the first frame, so the shell's scope is reachable.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _take(OpenShop f) {
    _category = f.category;
    _townName = f.town;
    _search.text = f.q ?? '';
    _min = null;
    _max = null;
    _sort = SortKey.newest;
  }

  /// Filters from a /shop link on a web page.
  void applyFilters(OpenShop f) {
    setState(() => _take(f));
    _reload();
  }

  Future<void> _start() async {
    final catalog = TabShellScope.of(context).services.catalog;
    try {
      final facets = await catalog.fetchFacets();
      final makers = await catalog.fetchMakers();
      if (!mounted) return;
      setState(() {
        _towns = facets.towns;
        _categories = facets.categories;
        _makers = makers;
        _facetsLoaded = true;
      });
    } catch (_) {
      // The grid still works without the rails.
    }
    await _reload();
  }

  CatalogFilters get _filters => CatalogFilters(
        q: _search.text.trim().isEmpty ? null : _search.text.trim(),
        category: _category,
        townId: _towns.where((t) => t.name == _townName).firstOrNull?.id,
        minPrice: _min,
        maxPrice: _max,
        sort: _sort,
      );

  bool get _filtered => _filters.isFiltered || (_townName != null && !_facetsLoaded);

  Future<void> _reload() => _load(0);

  Future<void> _load(int page) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await TabShellScope.of(context).services.catalog.fetchProducts(_filters, page: page, pageSize: _pageSize);
      if (!mounted || request != _request) return;
      setState(() {
        _products = page == 0 ? res.products : [..._products, ...res.products];
        _total = res.total;
        _page = page;
      });
    } catch (_) {
      if (mounted && request == _request) setState(() => _error = 'Could not load pieces. Pull down to try again.');
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _onSearchChanged() {
    _searchTimer?.cancel();
    _searchTimer = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _onScroll() {
    final pos = _scroll.position;
    if (!_loading && _products.length < _total && pos.pixels > pos.maxScrollExtent - 400) _load(_page + 1);
  }

  void _setCategory(String? slug) {
    setState(() => _category = slug);
    _reload();
  }

  void _setTown(String? name) {
    setState(() => _townName = name);
    _reload();
  }

  void _clearAll() {
    setState(() {
      _category = null;
      _townName = null;
      _min = null;
      _max = null;
      _sort = SortKey.newest;
    });
    _search.text = ''; // reloads through the search listener
    _reload();
  }

  Future<void> _openFilters() async {
    final picked = await showFilterSheet(context, (min: _min, max: _max, sort: _sort));
    if (picked == null) return;
    setState(() {
      _min = picked.min;
      _max = picked.max;
      _sort = picked.sort;
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final scope = TabShellScope.of(context);
    final firstName = scope.services.session.profile?.fullName.split(' ').first;
    final craft = _categories.where((c) => c.slug == _category).firstOrNull;
    final filtered = _filtered;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: atsuete,
        onRefresh: _reload,
        child: CustomScrollView(
          controller: _scroll,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverList.list(children: [
                Caps('Maayong adlaw${firstName == null || firstName.isEmpty ? '' : ', $firstName'}'),
                const SizedBox(height: 8),
                Text(craft?.name ?? 'What are you looking for?', style: display(30)),
                const SizedBox(height: 16),
                Row(children: [
                  Expanded(child: _SearchField(controller: _search)),
                  const SizedBox(width: 8),
                  _RoundButton(
                    icon: Icons.tune,
                    label: 'Price and sort',
                    dot: _min != null || _max != null || _sort != SortKey.newest,
                    onTap: _openFilters,
                  ),
                ]),
              ]),
            ),
            if (_categories.isNotEmpty)
              SliverToBoxAdapter(child: _CraftRail(categories: _categories, selected: _category, onSelect: _setCategory)),
            if (_towns.isNotEmpty)
              SliverToBoxAdapter(child: _TownChips(towns: _towns, selected: _townName, onSelect: _setTown)),
            if (!filtered && _makers.isNotEmpty)
              SliverToBoxAdapter(
                child: _MakersRail(
                  makers: _makers,
                  onTap: (m) => scope.actions.showWebPath('/artisans/${m.slug}'),
                  onAll: () => scope.actions.openWebPage('/artisans'),
                ),
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
              sliver: SliverToBoxAdapter(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: filtered ? 'Results' : 'All pieces', style: display(24)),
                  if (!(_loading && _products.isEmpty))
                    TextSpan(text: '   $_total ${_total == 1 ? 'piece' : 'pieces'}', style: body(13, color: muted)),
                ])),
              ),
            ),
            if (_error != null)
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverToBoxAdapter(child: Text(_error!, style: body(14, color: atsuete))),
              ),
            if (_products.isEmpty && !_loading && _error == null)
              SliverToBoxAdapter(child: _Empty(filtered: filtered, onClear: _clearAll))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 24,
                    childAspectRatio: 0.52,
                  ),
                  itemCount: _products.isEmpty && _loading ? 4 : _products.length,
                  itemBuilder: (context, i) {
                    if (_products.isEmpty) return const _CardSkeleton();
                    final p = _products[i];
                    return ProductCard(
                      product: p,
                      onTap: () => scope.actions.openProduct(p.slug),
                      onQuickAdd: () => addToCart(context, p, 1),
                    );
                  },
                ),
              ),
            if (_loading && _products.isNotEmpty)
              const SliverToBoxAdapter(
                child: Padding(padding: EdgeInsets.only(bottom: 32), child: Center(child: CircularProgressIndicator(color: atsuete))),
              ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ValueListenableBuilder(
        valueListenable: controller,
        builder: (context, value, _) => TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: body(16),
          decoration: InputDecoration(
            hintText: 'Search hablon, rattan, guitars…',
            hintStyle: body(15, color: muted),
            prefixIcon: const Icon(Icons.search, color: muted, size: 20),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(tooltip: 'Clear search', icon: const Icon(Icons.close, size: 18), onPressed: controller.clear),
            filled: true,
            fillColor: card,
            contentPadding: EdgeInsets.zero,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: line)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: line)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(99), borderSide: const BorderSide(color: atsuete)),
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, required this.onTap, this.dot = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      IconButton.outlined(
        tooltip: label,
        onPressed: onTap,
        icon: Icon(icon),
        style: IconButton.styleFrom(fixedSize: const Size.square(48), side: const BorderSide(color: line), backgroundColor: card),
      ),
      if (dot)
        const Positioned(top: 10, right: 10, child: SizedBox.square(dimension: 8, child: DecoratedBox(decoration: BoxDecoration(color: atsuete, shape: BoxShape.circle)))),
    ]);
  }
}

class _CraftRail extends StatefulWidget {
  const _CraftRail({required this.categories, required this.selected, required this.onSelect});
  final List<CategoryRef> categories;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  State<_CraftRail> createState() => _CraftRailState();
}

class _CraftRailState extends State<_CraftRail> {
  static const _itemWidth = 78.0;
  static const _gap = 12.0;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showSelected());
  }

  @override
  void didUpdateWidget(_CraftRail old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) WidgetsBinding.instance.addPostFrameCallback((_) => _showSelected());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Keeps a craft picked from a web link in view ("All" is item 0).
  void _showSelected() {
    if (!_scroll.hasClients) return;
    final index = widget.categories.indexWhere((c) => c.slug == widget.selected) + 1;
    final target = (index * (_itemWidth + _gap) - 40).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    Widget item({required String label, required bool active, required Widget image, required VoidCallback onTap}) => Semantics(
          button: true,
          selected: active,
          child: GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: _itemWidth,
              child: Column(children: [
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: active ? atsuete : Colors.transparent, width: 2)),
                  child: ClipOval(child: SizedBox.square(dimension: 58, child: image)),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: body(12, weight: active ? 600 : 400, color: active ? ink : muted, height: 1.2),
                ),
              ]),
            ),
          ),
        );

    final selected = widget.selected;
    return SizedBox(
      height: 128,
      child: ListView(
        controller: _scroll,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 20, 10, 0),
        children: [
          item(
            label: 'All',
            active: selected == null,
            image: const ColoredBox(color: line, child: Icon(Icons.grid_view_rounded, color: atsuete)),
            onTap: () => widget.onSelect(null),
          ),
          for (final c in widget.categories)
            item(
              // Short labels, as on the site: "Rattan and Wicker" → "Rattan".
              label: c.name.replaceFirst(RegExp(r' and .*'), ''),
              active: selected == c.slug,
              image: NetImage(standInFor(c.slug)),
              onTap: () => widget.onSelect(selected == c.slug ? null : c.slug),
            ),
        ].map((w) => Padding(padding: const EdgeInsets.symmetric(horizontal: _gap / 2), child: w)).toList(),
      ),
    );
  }
}

class _TownChips extends StatelessWidget {
  const _TownChips({required this.towns, required this.selected, required this.onSelect});
  final List<TownRef> towns;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        children: [
          const Center(child: Padding(padding: EdgeInsets.only(right: 8), child: Caps('Gikan sa', color: muted))),
          for (final t in towns)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected == t.name,
                showCheckmark: false,
                avatar: Icon(Icons.place, size: 15, color: selected == t.name ? mango : atsuete),
                label: Text(t.name),
                labelStyle: body(13.5, color: selected == t.name ? paper : ink),
                selectedColor: ink,
                backgroundColor: card,
                side: BorderSide(color: selected == t.name ? ink : line),
                shape: const StadiumBorder(),
                onSelected: (_) => onSelect(selected == t.name ? null : t.name),
              ),
            ),
        ],
      ),
    );
  }
}

class _MakersRail extends StatelessWidget {
  const _MakersRail({required this.makers, required this.onTap, required this.onAll});
  final List<ArtisanSummary> makers;
  final ValueChanged<ArtisanSummary> onTap;
  final VoidCallback onAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            Expanded(child: Text('Meet the makers', style: display(24))),
            TextButton(onPressed: onAll, child: const Text('All makers')),
          ]),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: makers.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final m = makers[i];
              return GestureDetector(
                onTap: () => onTap(m),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 220,
                    child: Stack(fit: StackFit.expand, children: [
                      NetImage(m.photoUrl ?? standInFor('hablon-weaving')),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Color(0xC0000000), Color(0x00000000)]),
                        ),
                      ),
                      Positioned(
                        left: 14,
                        right: 14,
                        bottom: 12,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(m.shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: display(18, color: Colors.white))),
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, size: 15, color: mango),
                          ]),
                          const SizedBox(height: 2),
                          Text(m.town?.name ?? 'Cebu', style: body(12, color: Colors.white70)),
                        ]),
                      ),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),
      ]),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.filtered, required this.onClear});
  final bool filtered;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 40),
      child: Column(children: [
        Text(filtered ? 'Walay nakit-an · Nothing found' : 'No crafts listed yet', textAlign: TextAlign.center, style: display(22)),
        const SizedBox(height: 8),
        Text(
          filtered ? 'Try another craft or town, or clear your filters.' : "Verified artisans' products will appear here as soon as they list them.",
          textAlign: TextAlign.center,
          style: body(14, color: muted),
        ),
        if (filtered) ...[
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onClear, child: const Text('Clear filters')),
        ],
      ]),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w) => Container(height: 14, width: w, margin: const EdgeInsets.only(top: 8), decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(4)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AspectRatio(aspectRatio: 4 / 5, child: DecoratedBox(decoration: BoxDecoration(color: line, borderRadius: BorderRadius.circular(16)))),
      bar(120),
      bar(60),
    ]);
  }
}
