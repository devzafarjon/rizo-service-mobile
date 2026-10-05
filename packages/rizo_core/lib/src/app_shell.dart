import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'i18n.dart';
import 'theme.dart';

/// The MaterialApp both apps use: brand theme, our own translations and the platform date pickers in uz / ru / en.
class RizoApp extends StatelessWidget {
  const RizoApp({super.key, required this.title, required this.home, this.providers = const []});
  final String title;
  final Widget home;
  final List<SingleChildWidget> providers;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider<Translator>.value(value: Translator.I), ...providers],
      child: Consumer<Translator>(
        builder: (context, translator, _) => MaterialApp(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          locale: Locale(translator.locale),
          supportedLocales: [for (final code in supportedLocales) Locale(code)],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          home: home,
        ),
      ),
    );
  }
}
