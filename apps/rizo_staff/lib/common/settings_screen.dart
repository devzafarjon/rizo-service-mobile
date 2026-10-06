import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Language, availability, server address and sign-out.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.repository});

  /// Present for technicians: signing out also clears the data kept for offline use.
  final TechRepository? repository;

  @override
  Widget build(BuildContext context) {
    final session = context.watch<StaffSession>();
    final user = session.user!;
    final translator = context.watch<Translator>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('mobile.settings'))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Section(
          child: Row(children: [
            CircleAvatar(radius: 26, backgroundColor: Brand.purpleTint, child: Text(user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(), style: TextStyle(fontWeight: FontWeight.w900, color: Brand.purple, fontSize: 20))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                Text(formatPhone(user.phone), style: TextStyle(color: Brand.muted)),
                const SizedBox(height: 4),
                Pill(_roleLabel(context, user), color: Brand.purple, background: Brand.purpleTint),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        if (user.isTechnician)
          Card(
            child: SwitchListTile(
              value: user.isAvailable,
              onChanged: (value) async {
                try {
                  await session.setAvailability(value);
                } catch (error) {
                  if (context.mounted) showSnack(context, context.errorText(error), error: true);
                }
              },
              title: Text(context.tr('shell.available'), style: const TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text(context.tr('mobile.availableHint')),
            ),
          ),
        if (user.isTechnician) const SizedBox(height: 12),
        Section(
          title: context.tr('common.language'),
          child: SegmentedChoice<String>(
            value: translator.locale,
            options: {for (final code in supportedLocales) code: context.tr('languages.$code')},
            onChanged: (code) => session.saveLocale(code),
          ),
        ),
        const SizedBox(height: 12),
        const ThemeModeSetting(),
        if (AppConfig.canChangeServer) ...[
          const SizedBox(height: 12),
          Card(child: ListTile(leading: const Icon(Icons.dns_outlined), title: Text(context.tr('mobile.serverTitle')), subtitle: Text(AppConfig.baseUrl), onTap: () => showServerDialog(context))),
        ],
        const SizedBox(height: 24),
        BusyButton(
          label: context.tr('common.signOut'),
          icon: Icons.logout,
          outlined: true,
          danger: true,
          onPressed: () async {
            final pending = repository?.pendingCount ?? 0;
            if (pending > 0) {
              final ok = await confirmDialog(context, context.tr('mobile.signOutPendingTitle'), body: context.tr('mobile.signOutPendingBody', params: {'count': pending}), confirmLabel: context.tr('common.signOut'));
              if (!ok) return;
            }
            await repository?.clearLocalData();
            await session.logout();
            if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
      ]),
    );
  }

  String _roleLabel(BuildContext context, StaffUser user) {
    if (user.isAdmin) return context.tr('shell.adminRole');
    if (user.isReceptionist) return context.tr('shell.receptionistRole');
    return user.technicianType == null ? context.tr('role.technician') : context.tr('techType.${user.technicianType}');
  }
}
