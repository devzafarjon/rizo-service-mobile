import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One set of brand colors. The apps read them through [Brand], which follows the active mode.
class _Palette {
  const _Palette({
    required this.purple,
    required this.purpleDark,
    required this.purpleTint,
    required this.orange,
    required this.orangeTint,
    required this.orangeText,
    required this.ink,
    required this.background,
    required this.surface,
    required this.surfaceSoft,
    required this.surfaceAlt,
    required this.border,
    required this.line,
    required this.muted,
    required this.faint,
    required this.subtle,
    required this.green,
    required this.greenTint,
    required this.red,
    required this.redTint,
    required this.amberTint,
    required this.amberText,
    required this.blue,
    required this.blueTint,
    required this.teal,
    required this.tealTint,
    required this.shadow,
  });

  final Color purple, purpleDark, purpleTint, orange, orangeTint, orangeText, ink, background;
  final Color surface, surfaceSoft, surfaceAlt, border, line, muted, faint, subtle;
  final Color green, greenTint, red, redTint, amberTint, amberText, blue, blueTint, teal, tealTint, shadow;
}

const _light = _Palette(
  purple: Color(0xFF7B00E0),
  purpleDark: Color(0xFF6500BD),
  purpleTint: Color(0xFFF5EBFD),
  orange: Color(0xFFF7941E),
  orangeTint: Color(0xFFFFF4E5),
  orangeText: Color(0xFFC56A00),
  ink: Color(0xFF1E293B),
  background: Color(0xFFF5F7FA),
  surface: Colors.white,
  surfaceSoft: Color(0xFFF9FAFB),
  surfaceAlt: Color(0xFFF3F4F6),
  border: Color(0xFFE5E7EB),
  line: Color(0xFFD1D5DB),
  muted: Color(0xFF6B7280),
  faint: Color(0xFF9CA3AF),
  subtle: Color(0xFF4B5563),
  green: Color(0xFF047857),
  greenTint: Color(0xFFECFDF5),
  red: Color(0xFFB91C1C),
  redTint: Color(0xFFFEF2F2),
  amberTint: Color(0xFFFFFBEB),
  amberText: Color(0xFF92400E),
  blue: Color(0xFF1D4ED8),
  blueTint: Color(0xFFEFF6FF),
  teal: Color(0xFF0F766E),
  tealTint: Color(0xFFF0FDFA),
  shadow: Color(0x14000000),
);

// Same hues as the website's dark mode (client/src/index.css, html.dark).
const _dark = _Palette(
  purple: Color(0xFFA050F0),
  purpleDark: Color(0xFFBB82FF),
  purpleTint: Color(0xFF2B1747),
  orange: Color(0xFFF7941E),
  orangeTint: Color(0xFF33230F),
  orangeText: Color(0xFFF7A94A),
  ink: Color(0xFFEDEFF5),
  background: Color(0xFF0F131C),
  surface: Color(0xFF181D2A),
  surfaceSoft: Color(0xFF1C2231),
  surfaceAlt: Color(0xFF232A3B),
  border: Color(0xFF2C3449),
  line: Color(0xFF3C4660),
  muted: Color(0xFF98A2BC),
  faint: Color(0xFF6F7A96),
  subtle: Color(0xFFC6CCDB),
  green: Color(0xFF34D399),
  greenTint: Color(0xFF0F2A22),
  red: Color(0xFFF87171),
  redTint: Color(0xFF3A1717),
  amberTint: Color(0xFF33260A),
  amberText: Color(0xFFFBBF24),
  blue: Color(0xFF7CB0FF),
  blueTint: Color(0xFF14264A),
  teal: Color(0xFF5EEAD4),
  tealTint: Color(0xFF0E2A2A),
  shadow: Color(0x66000000),
);

/// RIZO brand: purple and orange accents on a neutral base (never a full purple screen). The values switch between the
/// light and the dark palette; [ThemeController] flips [dark] and rebuilds the app.
class Brand {
  static bool dark = false;
  static _Palette get _p => dark ? _dark : _light;

  static Color get purple => _p.purple;
  static Color get purpleDark => _p.purpleDark;
  static Color get purpleTint => _p.purpleTint;
  static Color get orange => _p.orange;
  static Color get orangeTint => _p.orangeTint;
  static Color get orangeText => _p.orangeText;
  static Color get ink => _p.ink;
  static Color get background => _p.background;

  /// Cards, sheets, app bars and text fields.
  static Color get surface => _p.surface;

  /// Slightly raised grey areas inside a card (info boxes, hints).
  static Color get surfaceSoft => _p.surfaceSoft;

  /// Grey chips, segmented-control tracks, placeholders.
  static Color get surfaceAlt => _p.surfaceAlt;
  static Color get border => _p.border;

  /// Outlines of inputs and outlined buttons.
  static Color get line => _p.line;

  /// Secondary text, then fainter hints, then body text a little softer than [ink].
  static Color get muted => _p.muted;
  static Color get faint => _p.faint;
  static Color get subtle => _p.subtle;
  static Color get green => _p.green;
  static Color get greenTint => _p.greenTint;
  static Color get red => _p.red;
  static Color get redTint => _p.redTint;
  static Color get amberTint => _p.amberTint;
  static Color get amberText => _p.amberText;
  static Color get blue => _p.blue;
  static Color get blueTint => _p.blueTint;
  static Color get teal => _p.teal;
  static Color get tealTint => _p.tealTint;
  static Color get shadow => _p.shadow;
}

bool isTablet(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= 600;
bool isWide(BuildContext context) => MediaQuery.sizeOf(context).width >= 720;

/// Light, dark or follow the device. Saved on the device; the website keeps the same choice under `rizo_theme`.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  ThemeController._();
  static final ThemeController I = ThemeController._();

  static const _prefsKey = 'rizo_theme';
  ThemeMode _mode = ThemeMode.system;
  bool _observing = false;

  ThemeMode get mode => _mode;

  /// What is actually shown right now.
  bool get isDark => _resolve(_mode);

  bool _resolve(ThemeMode mode) {
    if (mode == ThemeMode.system) return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    return mode == ThemeMode.dark;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _mode = switch (prefs.getString(_prefsKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    Brand.dark = isDark;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    if (mode == _mode) return;
    _mode = mode;
    Brand.dark = isDark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, mode == ThemeMode.dark ? 'dark' : 'light');
    }
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode != ThemeMode.system) return;
    Brand.dark = isDark;
    notifyListeners();
  }
}

/// Marks every widget dirty so colours read from [Brand] are picked up again, without losing screens or typed text.
void rebuildEverything() {
  void visit(Element element) {
    element.markNeedsBuild();
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}

ThemeData buildTheme({bool dark = false}) {
  final p = dark ? _dark : _light;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B00E0),
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: p.purple,
    secondary: p.orange,
    surface: p.surface,
    onSurface: p.ink,
    error: p.red,
  );
  final border = OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p.line));
  return ThemeData(
    useMaterial3: true,
    brightness: dark ? Brightness.dark : Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: p.background,
    canvasColor: p.surface,
    dividerColor: p.border,
    appBarTheme: AppBarTheme(
      backgroundColor: p.surface,
      foregroundColor: p.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      titleTextStyle: TextStyle(color: p.ink, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      color: p.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: p.border)),
    ),
    dialogTheme: DialogThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: p.surface, surfaceTintColor: Colors.transparent),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: BorderSide(color: p.purple, width: 2)),
      hintStyle: TextStyle(color: p.faint),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        backgroundColor: p.purple,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: p.ink,
        side: BorderSide(color: p.line),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(foregroundColor: p.purple, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide.none,
      // Without these a chip takes the card's colour in dark mode and looks like bare text.
      backgroundColor: p.surfaceAlt,
      selectedColor: p.purpleTint,
      checkmarkColor: p.purple,
      labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: p.purpleTint,
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.white : p.faint),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? p.purple : p.surfaceAlt),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : p.line),
    ),
    snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
  );
}
