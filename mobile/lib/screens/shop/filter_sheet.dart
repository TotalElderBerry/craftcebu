import 'package:material_ui/material_ui.dart';

import '../../data/catalog_repo.dart';
import '../../theme.dart';

typedef PriceAndSort = ({double? min, double? max, SortKey sort});

const sortLabels = {SortKey.newest: 'Newest', SortKey.priceAsc: 'Lowest price', SortKey.priceDesc: 'Highest price'};

/// The price range and sort order, as a bottom sheet. Null when dismissed.
Future<PriceAndSort?> showFilterSheet(BuildContext context, PriceAndSort current) {
  return showModalBottomSheet<PriceAndSort>(
    context: context,
    isScrollControlled: true,
    backgroundColor: paper,
    showDragHandle: true,
    builder: (_) => _FilterSheet(current),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet(this.current);
  final PriceAndSort current;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late final _min = TextEditingController(text: widget.current.min?.round().toString() ?? '');
  late final _max = TextEditingController(text: widget.current.max?.round().toString() ?? '');
  late SortKey _sort = widget.current.sort;

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Widget _priceField(TextEditingController c, String label) => Expanded(
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          style: body(16),
          decoration: InputDecoration(
            labelText: label,
            prefixText: '₱ ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Price and sort', style: display(24)),
            const SizedBox(height: 20),
            Text('Price', style: body(15, weight: 600)),
            const SizedBox(height: 10),
            Row(children: [_priceField(_min, 'Min'), const SizedBox(width: 12), _priceField(_max, 'Max')]),
            const SizedBox(height: 20),
            Text('Sort by', style: body(15, weight: 600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in sortLabels.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _sort == entry.key,
                    onSelected: (_) => setState(() => _sort = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, (min: null, max: null, sort: SortKey.newest)),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.pop(context, (min: double.tryParse(_min.text), max: double.tryParse(_max.text), sort: _sort)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14)),
                  child: const Text('Show pieces'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
