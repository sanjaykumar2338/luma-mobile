// Flutter 3.50 currently reports the Material library import as deprecated
// while the app remains on the stable Material 3 API surface.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

const lumaCream = Color(0xFFF4F1EA);
const lumaSurface = Color(0xFFFBFAF6);
const lumaLine = Color(0xFFE2DED3);
const lumaInk = Color(0xFF111210);
const lumaCard = Color(0xFF1C1D1A);
const lumaCard2 = Color(0xFF262723);
const lumaMuted = Color(0xFF6E6C64);
const lumaMuted2 = Color(0xFF9C9A91);
const lumaLime = Color(0xFFC6F432);
const lumaLimeSoft = Color(0xFFE8F8B4);

class LumaMark extends StatelessWidget {
  const LumaMark({super.key, this.dark = false, this.size = 48});
  final bool dark;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size(size * 32 / 34, size),
        painter: _LumaMarkPainter(dark ? lumaSurface : lumaInk),
      );
}

class _LumaMarkPainter extends CustomPainter {
  const _LumaMarkPainter(this.baseColor);
  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.height / 34;
    canvas.scale(scale);
    final base = Paint()..color = baseColor;
    final accent = Paint()
      ..color = lumaLime
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 9, 34), const Radius.circular(1.5)),
        base);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 27, 30, 7), const Radius.circular(1.5)),
        base);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(13, 3, 3, 14), const Radius.circular(.5)),
        base);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(9.5, 7, 10, 3), const Radius.circular(.5)),
        base);
    canvas.drawLine(const Offset(14, 26), const Offset(31, 4), accent);
  }

  @override
  bool shouldRepaint(covariant _LumaMarkPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor;
}

ThemeData lumaTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: lumaCream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: lumaLime,
        brightness: Brightness.light,
        surface: lumaSurface,
      ).copyWith(
        primary: lumaInk,
        onPrimary: lumaSurface,
        secondary: lumaLime,
        onSecondary: lumaInk,
        surface: lumaSurface,
        onSurface: lumaInk,
        outline: lumaLine,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lumaCream,
        foregroundColor: lumaInk,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: lumaInk,
          fontSize: 26,
          height: 1.15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
      ),
      cardTheme: CardThemeData(
        color: lumaSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: lumaLine),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lumaSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: lumaLine),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: lumaLine),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: lumaInk, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lumaMuted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lumaInk,
          foregroundColor: lumaSurface,
          minimumSize: const Size.fromHeight(56),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lumaInk,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: lumaLine, width: 1.2),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 92,
        backgroundColor: lumaSurface,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );

class LumaEyebrow extends StatelessWidget {
  const LumaEyebrow(this.text, {super.key, this.dark = false});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          color: dark ? lumaMuted2 : lumaMuted,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.1,
        ),
      );
}

class LumaTag extends StatelessWidget {
  const LumaTag(this.text, {super.key, this.dark = false});
  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: dark ? lumaCard2 : lumaLimeSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            color: dark ? lumaLime : lumaInk,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .8,
          ),
        ),
      );
}

class LumaDarkCard extends StatelessWidget {
  const LumaDarkCard({required this.child, super.key, this.padding});
  final Widget child;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: lumaInk,
          borderRadius: BorderRadius.circular(28),
        ),
        child: child,
      );
}

class LumaAccentButton extends StatelessWidget {
  const LumaAccentButton(
      {required this.label, required this.onPressed, super.key});
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: lumaLime,
          foregroundColor: lumaInk,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, size: 22),
          ],
        ),
      );
}

class LumaProgressBar extends StatelessWidget {
  const LumaProgressBar({required this.value, super.key});
  final double value;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: value,
          minHeight: 8,
          backgroundColor: lumaCard2,
          color: lumaLime,
        ),
      );
}

class LumaBottomBar extends StatelessWidget {
  const LumaBottomBar(
      {required this.index, required this.onChanged, super.key});
  final int index;
  final ValueChanged<int> onChanged;

  static const items = [
    (Icons.home_outlined, Icons.home, 'Today'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Library'),
    (Icons.add, Icons.add, 'New study'),
    (Icons.calendar_month_outlined, Icons.calendar_month, 'Plans'),
    (Icons.person_outline, Icons.person, 'You'),
  ];

  @override
  Widget build(BuildContext context) => Material(
        color: lumaSurface,
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 92,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (itemIndex) {
                final item = items[itemIndex];
                if (itemIndex == 2) {
                  return Semantics(
                    button: true,
                    label: 'New study',
                    child: InkWell(
                      onTap: () => onChanged(itemIndex),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: const BoxDecoration(
                          color: lumaInk,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(item.$2, color: lumaLime, size: 32),
                      ),
                    ),
                  );
                }
                final active = index == itemIndex;
                return Semantics(
                  button: true,
                  label: item.$3,
                  selected: active,
                  child: InkWell(
                    onTap: () => onChanged(itemIndex),
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox(
                      width: 62,
                      height: 76,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(active ? item.$2 : item.$1,
                              color: active ? lumaInk : lumaMuted2, size: 25),
                          const SizedBox(height: 4),
                          Text(item.$3,
                              style: TextStyle(
                                  color: active ? lumaInk : lumaMuted2,
                                  fontSize: 11,
                                  fontWeight: active
                                      ? FontWeight.w700
                                      : FontWeight.w500)),
                          const SizedBox(height: 4),
                          if (active)
                            Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                    color: lumaLime, shape: BoxShape.circle)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      );
}
