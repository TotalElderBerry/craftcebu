import 'package:material_ui/material_ui.dart';

import '../../data/models.dart';
import '../../theme.dart';
import '../common.dart';

/// A product in a grid or rail, like the site's ProductCard.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, required this.onTap, required this.onQuickAdd});

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onQuickAdd;

  @override
  Widget build(BuildContext context) {
    final p = product;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 4 / 5,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NetImage(p.coverImage),
                  if (p.artisan.town != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      right: 8,
                      child: Align(alignment: Alignment.topLeft, child: _TownChip(p.artisan.town!.name)),
                    ),
                  if (p.stock == 0)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: ink.withValues(alpha: 0.85), borderRadius: BorderRadius.circular(99)),
                        child: Text('Sold out', style: body(12, weight: 500, color: Colors.white)),
                      ),
                    )
                  else
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: Semantics(
                        button: true,
                        label: 'Add ${p.name} to cart',
                        excludeSemantics: true,
                        child: Material(
                          color: atsuete,
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            key: ValueKey('add-${p.id}'),
                            customBorder: const CircleBorder(),
                            onTap: onQuickAdd,
                            child: const SizedBox.square(dimension: 40, child: Icon(Icons.add, color: Colors.white, size: 22)),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: body(15, weight: 500, height: 1.25)),
          const SizedBox(height: 2),
          Row(
            children: [
              Flexible(child: Text(p.artisan.shopName, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(13, color: muted))),
              const SizedBox(width: 4),
              const Icon(Icons.verified, size: 14, color: atsuete),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: Text(peso(p.price), style: display(18))),
              if (p.rating != null) ...[
                const Icon(Icons.star_rounded, size: 16, color: mango),
                const SizedBox(width: 2),
                Text(p.rating!.toStringAsFixed(1), style: body(12, color: muted)),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TownChip extends StatelessWidget {
  const _TownChip(this.name);
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(color: paper.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(99)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 12, color: atsuete),
          const SizedBox(width: 3),
          Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: body(12, weight: 500))),
        ],
      ),
    );
  }
}
