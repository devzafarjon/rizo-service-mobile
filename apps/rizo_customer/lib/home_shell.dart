import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'centers_screen.dart';
import 'new_request_screen.dart';
import 'notifications_screen.dart';
import 'register_product_screen.dart';
import 'request_detail_screen.dart';
import 'requests_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int index = 0;
  int unread = 0;
  Timer? _poll;
  final _requests = GlobalKey<RequestsScreenState>();

  @override
  void initState() {
    super.initState();
    _unread();
    _poll = Timer.periodic(const Duration(seconds: 60), (_) => _unread());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _unread() async {
    try {
      final r = asMap(await context.read<CustomerSession>().api.get('/api/customer/notifications'));
      if (mounted) setState(() => unread = asInt(r['unreadCount']));
    } catch (_) {}
  }

  Future<void> _newRequest() async {
    final id = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const NewRequestScreen()));
    if (id != null && mounted) {
      setState(() => index = 0);
      _requests.currentState?.reload();
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: id)));
      _requests.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final pages = <Widget>[
      RequestsScreen(key: _requests, onNew: _newRequest),
      NotificationsScreen(onChanged: _unread),
      const _MoreScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: index, children: pages),
      floatingActionButton: index == 0 ? FloatingActionButton.extended(backgroundColor: Brand.purple, foregroundColor: Colors.white, onPressed: _newRequest, icon: const Icon(Icons.add), label: Text(tr('nav.newRequest'))) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) {
          setState(() => index = i);
          if (i == 1) _unread();
        },
        destinations: [
          NavigationDestination(icon: const Icon(Icons.assignment_outlined), selectedIcon: const Icon(Icons.assignment), label: tr('nav.myRequests')),
          NavigationDestination(icon: unread > 0 ? Badge(label: Text('$unread'), child: const Icon(Icons.notifications_none)) : const Icon(Icons.notifications_none), label: tr('nav.notifications')),
          NavigationDestination(icon: const Icon(Icons.menu), label: tr('mobile.more')),
        ],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context) {
    final user = context.watch<CustomerSession>().user!;
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    Widget tile(IconData icon, String label, Widget page) => Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(leading: Icon(icon, color: Brand.purple), title: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)), trailing: const Icon(Icons.chevron_right), onTap: () => open(page)));
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('mobile.more'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        Section(
          child: Row(children: [
            CircleAvatar(radius: 24, backgroundColor: Brand.purpleTint, child: Text(user.name.isEmpty ? '?' : user.name.characters.first.toUpperCase(), style: TextStyle(color: Brand.purple, fontWeight: FontWeight.w900, fontSize: 20))),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(user.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(formatPhone(user.phone), style: TextStyle(color: Brand.muted))])),
          ]),
        ),
        const SizedBox(height: 12),
        tile(Icons.add_box_outlined, context.tr('nav.registerProduct'), const RegisterProductScreen()),
        tile(Icons.place_outlined, context.tr('nav.centers'), const CentersScreen()),
        tile(Icons.settings_outlined, context.tr('mobile.settings'), const SettingsScreen()),
      ]),
    );
  }
}
