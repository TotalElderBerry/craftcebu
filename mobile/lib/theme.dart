import 'package:material_ui/material_ui.dart';

// CraftCebu palette (src/style.css).
const paper = Color(0xFFFAF6EE);
const ink = Color(0xFF1F1A17);
const atsuete = Color(0xFFAE3D24);
const mango = Color(0xFFEDB54A);
const muted = Color(0xFF6B635C);
const line = Color(0xFFE7DFD3);
const card = Color(0xFFFFFDF8);

// Both fonts are variable, so weight is set through the font's own axis.
TextStyle display(double size, {int weight = 500, Color color = ink}) => TextStyle(
      fontFamily: 'Fraunces',
      fontSize: size,
      height: 1.1,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(weight.toDouble()), FontVariation('opsz', size.clamp(9, 144))],
    );

TextStyle body(double size, {int weight = 400, Color color = ink, double height = 1.4}) => TextStyle(
      fontFamily: 'DMSans',
      fontSize: size,
      height: height,
      color: color,
      fontWeight: FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)],
      fontVariations: [FontVariation.weight(weight.toDouble())],
    );

ThemeData craftCebuTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: atsuete, primary: atsuete, surface: paper);
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: paper,
    fontFamily: 'DMSans',
    textTheme: TextTheme(
      bodyLarge: body(16),
      bodyMedium: body(15),
      bodySmall: body(13, color: muted),
      labelLarge: body(15, weight: 600),
      titleMedium: body(16, weight: 600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ink,
      contentTextStyle: body(14, color: Colors.white),
      actionTextColor: mango,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: card,
      indicatorColor: atsuete.withValues(alpha: 0.12),
      labelTextStyle: WidgetStatePropertyAll(body(12, weight: 500)),
    ),
  );
}
