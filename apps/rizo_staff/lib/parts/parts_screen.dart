import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'parts_orders.dart';
import 'parts_plan.dart';
import 'parts_suppliers.dart';

/// Spare-part control: jobs waiting for parts, what to order next, orders and deliveries, suppliers.
/// The same four views as the website's `/app/part-orders`.
class PartsControlScreen extends StatefulWidget {
  const PartsControlScreen({super.key, this.bell, this.initialTab = 1, this.standalone = true});

  /// The notifications bell (admin and warehouse), shown in the top bar.
  final Widget? bell;

  /// 0 what to order, 1 waiting jobs, 2 orders, 3 suppliers.
  final int initialTab;

  /// Pushed from a menu (has a back button) or used as a tab of the home screen.
  final bool standalone;
  @override
  State<PartsControlScreen> createState() => _PartsControlScreenState();
}

class _PartsControlScreenState extends State<PartsControlScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this, initialIndex: widget.initialTab.clamp(0, 3));
  PartsOverview? overview;
  int _version = 0;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadOverview() async {
    try {
      final r = await _api.get('/api/staff/part-orders/overview');
      if (mounted) setState(() => overview = PartsOverview(asMap(asMap(r)['overview'])));
    } catch (_) {}
  }

  /// Something changed (an order was placed or received): every view reloads and the numbers refresh.
  void _changed() {
    _loadOverview();
    setState(() => _version += 1);
  }

  Future<void> _newOrder() async {
    final saved = await showOrderSheet(context);
    if (saved == true) _changed();
  }

  Widget _stat(String label, int? value, {bool bad = false, int tab = 1}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => _tabs.animateTo(tab),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Brand.muted)),
            Text(value == null ? '–' : '$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bad && (value ?? 0) > 0 ? Brand.red : Brand.ink)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final o = overview;
    final tabs = [
      (tr('parts.tab.recommend'), o?.toOrder),
      (tr('parts.tab.waiting'), o?.waitingRequests),
      (tr('parts.tab.orders'), o?.openOrders),
      (tr('parts.tab.suppliers'), null),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Text(context.tr('parts.ordersTitle')),
        actions: [?widget.bell, IconButton(onPressed: _changed, icon: const Icon(Icons.refresh))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _newOrder, icon: const Icon(Icons.add), label: Text(context.tr('parts.newOrder'))),
      body: Column(children: [
        // One scrolling row of tiles keeps the lists high on a phone.
        SizedBox(
          height: 104,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            children: [
              SizedBox(width: 156, child: _stat(context.tr('parts.stat.waiting'), o?.waitingRequests, tab: 1)),
              const SizedBox(width: 8),
              SizedBox(width: 156, child: _stat(context.tr('parts.stat.noOrder'), o?.noOrder, bad: true, tab: 1)),
              const SizedBox(width: 8),
              SizedBox(width: 156, child: _stat(context.tr('parts.stat.late'), o?.lateOrders, bad: true, tab: 2)),
              const SizedBox(width: 8),
              SizedBox(width: 156, child: _stat(context.tr('parts.stat.toOrder'), o?.toOrder, tab: 0)),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final t in tabs)
              Tab(child: Row(mainAxisSize: MainAxisSize.min, children: [Text(t.$1), if ((t.$2 ?? 0) > 0) ...[const SizedBox(width: 6), Badge(label: Text('${t.$2}'), backgroundColor: Brand.purple)]])),
          ],
        ),
        Expanded(
          child: TabBarView(controller: _tabs, children: [
            RecommendationsTab(key: ValueKey('rec-$_version'), onChanged: _changed),
            WaitingTab(key: ValueKey('wait-$_version'), onChanged: _changed),
            OrdersTab(key: ValueKey('ord-$_version'), onChanged: _changed),
            SuppliersTab(key: ValueKey('sup-$_version'), onChanged: _changed),
          ]),
        ),
      ]),
    );
  }
}
