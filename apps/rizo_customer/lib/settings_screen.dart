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
        const SizedBox(height: 12),
        Section(
          title: context.tr('account.channel'),
          hint: context.tr('account.channelBody'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SegmentedChoice<String>(
              value: user.preferredChannel,
              options: {for (final c in const ['both', 'sms', 'telegram']) c: context.tr('account.channels.$c')},
              onChanged: (c) async {
                try {
                  await session.setChannel(c);
                } catch (e) {
                  if (context.mounted) showSnack(context, context.errorText(e), error: true);
                }
              },
            ),
            const SizedBox(height: 8),
            Text(user.telegramLinked ? context.tr('account.telegramLinked') : context.tr('account.telegramHow'), style: TextStyle(color: Brand.muted, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 12),
        Section(
          title: context.tr('account.data'),
          hint: context.tr('account.dataBody'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            OutlinedButton.icon(onPressed: () => openUri(context, Uri.parse('${AppConfig.webUrl}/portal/account')), icon: const Icon(Icons.download_outlined), label: Text(context.tr('account.export'))),
            const SizedBox(height: 12),
            if (user.deletionRequested) ...[
              Text(context.tr('account.deletePending'), style: TextStyle(color: Brand.amberText, fontWeight: FontWeight.w700)),
              TextButton(
                onPressed: () async {
                  try {
                    await session.setDeletionRequested(false);
                    if (context.mounted) showSnack(context, context.tr('account.deleteCancelled'));
                  } catch (e) {
                    if (context.mounted) showSnack(context, context.errorText(e), error: true);
                  }
                },
                child: Text(context.tr('account.deleteWithdraw')),
              ),
            ] else ...[
              Text(context.tr('account.deleteBody'), style: TextStyle(color: Brand.muted, fontSize: 13)),
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Brand.red),
                onPressed: () async {
                  if (!await confirmDialog(context, context.tr('account.deleteAsk'), body: context.tr('account.deleteConfirm'), confirmLabel: context.tr('account.deleteAsk'))) return;
                  try {
                    await session.setDeletionRequested(true);
                    if (context.mounted) showSnack(context, context.tr('account.deleteAsked'));
                  } catch (e) {
                    if (context.mounted) showSnack(context, context.errorText(e), error: true);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(context.tr('account.deleteAsk')),
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          TextButton(onPressed: () => openUri(context, Uri.parse('${AppConfig.webUrl}/privacy')), child: Text(context.tr('legal.privacy'))),
          TextButton(onPressed: () => openUri(context, Uri.parse('${AppConfig.webUrl}/terms')), child: Text(context.tr('legal.terms'))),
        ]),
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
