import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CustomerSession>();
    final translator = context.watch<Translator>();
    final user = session.user!;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('mobile.settings'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Section(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)), Text(formatPhone(user.phone), style: TextStyle(color: Brand.muted)), if (user.address != null) Text(user.address!, style: const TextStyle(fontSize: 13))])),
        const SizedBox(height: 12),
        Section(title: context.tr('common.language'), child: SegmentedChoice<String>(value: translator.locale, options: {for (final c in supportedLocales) c: context.tr('languages.$c')}, onChanged: (c) => session.saveLocale(c))),
        const SizedBox(height: 12),
        const ThemeModeSetting(),
        if (AppConfig.canChangeServer) ...[const SizedBox(height: 12), Card(child: ListTile(leading: const Icon(Icons.dns_outlined), title: Text(context.tr('mobile.serverTitle')), subtitle: Text(AppConfig.baseUrl), onTap: () => showServerDialog(context)))],
        const SizedBox(height: 24),
        BusyButton(
          label: context.tr('common.signOut'),
          icon: Icons.logout,
          outlined: true,
          danger: true,
          onPressed: () async {
            await session.logout();
            if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      ]),
    );
  }
}
