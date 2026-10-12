import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'history_tab.dart';
import 'list_tab.dart';
import 'restock_tab.dart';
import 'source_picker.dart';
import 'stock_tab.dart';
import 'transfers_tab.dart';

/// Warehouses: the keeper's workplace. Requests from technicians and branch admins to send, parts on the way in, the shelf with
/// counts and minimums, restocking from the quickest source, the history, and (admin) the list of all warehouses.
/// The same views as the website's `/app/warehouses`.
class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key, this.bell, this.standalone = true});
  final Widget? bell;
  final bool standalone;
  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> with TickerProviderStateMixin {
  List<Warehouse> warehouses = [];
  String? mineId;
  bool canManageAll = false;
  bool manages = false;
  String? selectedId;
  Object? error;
  bool loading = true;
  int _version = 0;
  TabController? _tabs;

  StaffUser get _user => context.read<StaffSession>().user!;
  ApiClient get _api => context.read<StaffSession>().api;
  bool get _isAdmin => _user.isAdmin;
  int get _tabCount => _isAdmin ? 6 : 5;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabCount, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final all = asMap(await _api.get('/api/staff/warehouses'));
      final mine = asMap(await _api.get('/api/staff/warehouses/mine'));
      if (!mounted) return;
      setState(() {
        warehouses = asList(all['warehouses']).map((e) => Warehouse(asMap(e))).toList();
        mineId = mine['warehouseId']?.toString();
        canManageAll = mine['canManageAll'] == true;
        manages = mine['manages'] == true;
        error = null;
        final visible = _visible;
        if (selectedId == null || !visible.any((w) => w.id == selectedId)) {
          selectedId = visible.any((w) => w.id == mineId) ? mineId : visible.firstOrNull?.id;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// A keeper who looks after one warehouse sees only that one.
  List<Warehouse> get _visible {
    final locked = _user.isWarehouse && !canManageAll;
    if (locked) return warehouses.where((w) => w.id == mineId).toList();
    return warehouses.where((w) => w.isActive || _isAdmin).toList();
  }

  void _changed() {
    _load();
    setState(() => _version += 1);
  }

  Widget _stat(String label, int value, {bool bad = false, int? tab}) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: tab == null ? null : () => _tabs!.animateTo(tab),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Brand.muted)),
            Text('$value', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bad && value > 0 ? Brand.red : Brand.ink)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final visible = _visible;
    final selected = visible.where((w) => w.id == selectedId).firstOrNull;
    final canAct = manages && (canManageAll || mineId == selectedId);
    final canReceive = canAct || mineId == selectedId;
    const canAsk = true;
    final tabs = <(String, int?)>[
      (tr('warehouse.tab.requests'), selected?.toSend),
      (tr('warehouse.tab.incoming'), selected?.arriving),
      (tr('warehouse.tab.stock'), null),
      (tr('warehouse.tab.restock'), selected?.low),
      (tr('warehouse.tab.history'), null),
      if (_isAdmin) (tr('warehouse.tab.list'), null),
    ];
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.standalone,
        title: Text(context.tr('warehouse.title')),
        actions: [?widget.bell, IconButton(onPressed: _changed, icon: const Icon(Icons.refresh))],
      ),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : Column(children: [
                  if (visible.length > 1)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedId,
                        isExpanded: true,
                        decoration: InputDecoration(isDense: true, labelText: context.tr('warehouse.choose')),
                        items: [for (final w in visible) DropdownMenuItem(value: w.id, child: Text('${w.name} · ${regionName(w.regionCode)}${w.isActive ? '' : ' (${context.tr('warehouse.off')})'}', overflow: TextOverflow.ellipsis))],
                        onChanged: (v) => setState(() {
                          selectedId = v;
                          _version += 1;
                        }),
                      ),
                    ),
                  if (selected != null) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          [context.tr('warehouse.kind.${selected.kind}'), regionName(selected.regionCode), if (selected.serviceCenterName != null) selected.serviceCenterName!, if (selected.keepers.isNotEmpty) '${context.tr('warehouse.keepers')}: ${selected.keepers.join(', ')}'].join(' · '),
                          style: TextStyle(color: Brand.muted, fontSize: 13),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 104,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        children: [
                          SizedBox(width: 148, child: _stat(context.tr('warehouse.stat.units'), selected.units, tab: 2)),
                          const SizedBox(width: 8),
                          SizedBox(width: 148, child: _stat(context.tr('warehouse.stat.toSend'), selected.toSend, tab: 0)),
                          const SizedBox(width: 8),
                          SizedBox(width: 148, child: _stat(context.tr('warehouse.stat.arriving'), selected.arriving, tab: 1)),
                          const SizedBox(width: 8),
                          SizedBox(width: 148, child: _stat(context.tr('warehouse.stat.low'), selected.low, bad: true, tab: 3)),
                        ],
                      ),
                    ),
                  ],
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
                    child: selectedId == null
                        ? EmptyView(title: context.tr('warehouse.noStockTitle'))
                        : TabBarView(controller: _tabs, children: [
                            TransfersTab(key: ValueKey('out-$selectedId-$_version'), warehouseId: selectedId!, direction: 'out', canAct: canAct, canReceive: canReceive, canAsk: canAsk, onChanged: _changed),
                            TransfersTab(key: ValueKey('in-$selectedId-$_version'), warehouseId: selectedId!, direction: 'in', canAct: canAct, canReceive: canReceive, canAsk: canAsk, onChanged: _changed),
                            StockTab(key: ValueKey('stock-$selectedId-$_version'), warehouseId: selectedId!, canAct: canAct, canAsk: canAsk, onChanged: _changed),
                            RestockTab(key: ValueKey('restock-$selectedId-$_version'), warehouseId: selectedId!, canAct: canAct, onChanged: _changed),
                            HistoryTab(key: ValueKey('hist-$selectedId-$_version'), warehouseId: selectedId!),
                            if (_isAdmin)
                              WarehouseListTab(
                                warehouses: warehouses,
                                onOpen: (id) => setState(() {
                                  selectedId = id;
                                  _version += 1;
                                  _tabs!.animateTo(0);
                                }),
                                onChanged: _changed,
                              ),
                          ]),
                  ),
                ]),
    );
  }
}
