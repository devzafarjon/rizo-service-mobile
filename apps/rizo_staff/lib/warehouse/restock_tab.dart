import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'source_picker.dart';

/// Parts below the minimum with the quickest places to get them; one tap sends every request.
class RestockTab extends StatefulWidget {
  const RestockTab({super.key, required this.warehouseId, required this.canAct, required this.onChanged});
  final String warehouseId;
  final bool canAct;
  final VoidCallback onChanged;
  @override
  State<RestockTab> createState() => _RestockTabState();
}

class _RestockTabState extends State<RestockTab> {
  List<RestockSuggestion> rows = [];
  final Map<String, TextEditingController> _qty = {};
  final Map<String, String> _choice = {};
  final Set<String> _off = {};
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = rows.isEmpty);
    try {
      final r = await _api.get('/api/staff/warehouses/${widget.warehouseId}/restock');
      final list = asList(asMap(r)['suggestions']).map((e) => RestockSuggestion(asMap(e))).toList();
      if (!mounted) return;
      setState(() {
        rows = list;
        _off.clear();
        _choice.clear();
        for (final row in list) {
          final id = row.item.partId;
          (_qty[id] ??= TextEditingController()).text = '${row.recommended}';
          final best = row.options.where((o) => o.recommended).firstOrNull;
          if (best != null) _choice[id] = best.key;
        }
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  int get _chosen => rows.where((r) => !_off.contains(r.item.partId) && _choice.containsKey(r.item.partId)).length;

  Future<void> _send() async {
    final items = [
      for (final row in rows)
        if (!_off.contains(row.item.partId) && _choice.containsKey(row.item.partId))
          {'sparePartId': row.item.partId, 'quantity': (int.tryParse(_qty[row.item.partId]?.text.trim() ?? '') ?? row.recommended).clamp(1, 100000), 'from': _choice[row.item.partId]!.replaceFirst('wh:', '')},
    ];
    try {
      final r = asMap(await _api.post('/api/staff/warehouses/${widget.warehouseId}/restock', body: {'items': items}));
      if (!mounted) return;
      showSnack(context, tr('warehouse.restockSent', params: {'transfers': asInt(r['transfers']), 'orders': asInt(r['orders'])}));
      widget.onChanged();
      _load();
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    if (loading) return const LoadingView();
    if (error != null) return ErrorView(error: error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: rows.isEmpty
          ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('warehouse.restockEmptyTitle'), body: context.tr('warehouse.restockEmptyBody')))])
          : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
              Text(context.tr('warehouse.restockIntro'), style: TextStyle(color: Brand.muted)),
              const SizedBox(height: 10),
              for (final row in rows)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Opacity(
                    opacity: _off.contains(row.item.partId) ? 0.55 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Checkbox(
                            value: !_off.contains(row.item.partId),
                            onChanged: widget.canAct ? (v) => setState(() => v == true ? _off.remove(row.item.partId) : _off.add(row.item.partId)) : null,
                          ),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(row.item.part.localized(locale), style: const TextStyle(fontWeight: FontWeight.w900)),
                              Text(
                                context.tr('warehouse.restockState', params: {'have': row.item.quantity, 'min': row.item.effectiveMin ?? 0, 'coming': row.item.onOrder + row.item.incoming}),
                                style: TextStyle(color: Brand.muted, fontSize: 12.5),
                              ),
                            ]),
                          ),
                          SizedBox(width: 72, child: TextField(controller: _qty[row.item.partId], enabled: widget.canAct, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(isDense: true))),
                        ]),
                        const SizedBox(height: 8),
                        SourcePicker(options: row.options, value: _choice[row.item.partId] ?? '', onChanged: (o) => setState(() => _choice[row.item.partId] = o.key)),
                      ]),
                    ),
                  ),
                ),
              if (widget.canAct) BusyButton(label: context.tr('warehouse.restockSend', params: {'count': _chosen}), enabled: _chosen > 0, onPressed: _send),
            ]),
    );
  }
}
