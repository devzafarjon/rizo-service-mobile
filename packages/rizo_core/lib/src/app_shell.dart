import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'i18n.dart';
import 'theme.dart';

/// The MaterialApp both apps use: brand theme (light, dark or follow the device), our own translations and the
/// platform date pickers in uz / ru / en.
class RizoApp extends StatefulWidget {
  const RizoApp({super.key, required this.title, required this.home, this.providers = const []});
  final String title;
  final Widget home;
  final List<SingleChildWidget> providers;

  @override
  State<RizoApp> createState() => _RizoAppState();
}

class _RizoAppState extends State<RizoApp> {
  @override
  void initState() {
    super.initState();
    ThemeController.I.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    ThemeController.I.removeListener(_onThemeChanged);
    super.dispose();
  }

  // Colours come from [Brand], which most widgets read without depending on the Theme, so rebuild the whole tree.
  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {});
    rebuildEverything();
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.I;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<Translator>.value(value: Translator.I),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ...widget.providers,
      ],
      child: Consumer<Translator>(
        builder: (context, translator, _) => MaterialApp(
          title: widget.title,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          darkTheme: buildTheme(dark: true),
          themeMode: theme.mode,
          locale: Locale(translator.locale),
          supportedLocales: [for (final code in supportedLocales) Locale(code)],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: widget.home,
        ),
      ),
    );
  }
}
