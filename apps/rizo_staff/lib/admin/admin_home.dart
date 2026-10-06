import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../common/settings_screen.dart';
import '../tech/scan_screen.dart';
import 'dashboard_screen.dart';
import 'more_screens.dart';
import 'request_detail_screen.dart';
import 'requests_screen.dart';

/// Admin / dispatcher and front desk. Phone: bottom bar. Tablet: side rail.
class AdminHome extends StatefulWidget {
  const AdminHome({super.key});
  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  int index = 0;
  int unread = 0;
  Timer? _poll;

  StaffUser get _user => context.read<StaffSession>().user!;

  @override
  void initState() {
    super.initState();
    if (_user.isAdmin) {
      _unread();
      _poll = Timer.periodic(const Duration(seconds: 60), (_) => _unread());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _unread() async {
    try {
      final r = asMap(await context.read<StaffSession>().api.get('/api/staff/alerts'));
      if (mounted) setState(() => unread = asInt(r['unreadCount']));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final user = context.watch<StaffSession>().user!;
    final tabs = <({String label, IconData icon, Widget page, int badge})>[
      if (user.isAdmin) (label: tr('nav.dashboard'), icon: Icons.dashboard_outlined, page: const DashboardScreen(), badge: 0),
      (label: tr('nav.requests'), icon: Icons.assignment_outlined, page: const RequestsScreen(), badge: 0),
      if (user.isAdmin) (label: tr('nav.notifications'), icon: Icons.notifications_none, page: AlertsScreen(key: ValueKey(unread)), badge: unread),
      (label: tr('mobile.more'), icon: Icons.menu, page: const _MoreScreen(), badge: 0),
    ];
    final current = index.clamp(0, tabs.length - 1);
    final wide = isWide(context);
    Widget badge(IconData icon, int count) => count > 0 ? Badge(label: Text('$count'), child: Icon(icon)) : Icon(icon);
    final body = IndexedStack(index: current, children: [for (final t in tabs) t.page]);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: current,
            onDestinationSelected: (i) => setState(() => index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LogoMark(height: 34)),
            destinations: [for (final t in tabs) NavigationRailDestination(icon: badge(t.icon, t.badge), label: Text(t.label))],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: current,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [for (final t in tabs) NavigationDestination(icon: badge(t.icon, t.badge), label: t.label)],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<StaffSession>().user!;
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    Widget tile(IconData icon, String label, Widget page) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(icon, color: Brand.purple), title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right), onTap: () => open(page)));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('mobile.more'))),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        tile(Icons.event_note_outlined, context.tr('calendar.title'), const VisitsScreen()),
        tile(Icons.engineering_outlined, context.tr('kanban.technicians'), const TechniciansScreen()),
        tile(Icons.inventory_2_outlined, context.tr('nav.partOrders'), const PartOrdersScreen()),
        tile(Icons.people_outline, context.tr('nav.customers'), const CustomersScreen()),
        tile(
          Icons.qr_code_scanner,
          context.tr('nav.scan'),
          ScanScreen(resolve: (displayId) async {
            final r = asMap(await context.read<StaffSession>().api.get('/api/staff/requests/lookup/${Uri.encodeComponent(displayId)}'));
            return RequestDetailScreen(requestId: asMap(r['request'])['id'].toString());
          }),
        ),
        tile(Icons.settings_outlined, context.tr('mobile.settings'), const SettingsScreen()),
        const SizedBox(height: 8),
        Center(child: Text('${user.name} · ${formatPhone(user.phone)}', style: TextStyle(color: Brand.faint, fontSize: 12))),
      ]),
    );
  }
}
