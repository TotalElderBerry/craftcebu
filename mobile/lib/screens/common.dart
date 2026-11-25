import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Whole pesos with thousands separators, like the site's peso().
String peso(num value) {
  final digits = value.round().abs().toString();
  final grouped = digits.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  return '${value < 0 ? '-' : ''}₱$grouped';
}

/// Years since a maker started, or null when unknown (like yearsInCraft()).
int? yearsInCraft(int? craftSince) => craftSince == null ? null : (DateTime.now().year - craftSince).clamp(1, 200);

/// A network photo with a soft placeholder while loading or on failure.
class NetImage extends StatelessWidget {
  const NetImage(this.url, {super.key, this.fit = BoxFit.cover});

  final String url;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      fit: fit,
      errorBuilder: (_, _, _) => const ColoredBox(color: line),
      frameBuilder: (context, child, frame, sync) => frame == null && !sync ? const ColoredBox(color: line) : child,
    );
  }
}

/// Small uppercase label with wide tracking, like the site's .caps.
class Caps extends StatelessWidget {
  const Caps(this.text, {super.key, this.color = atsuete});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: body(11.5, weight: 600, color: color).copyWith(letterSpacing: 1.6));
}

void showMessage(BuildContext context, String text, {SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), action: action));
}
