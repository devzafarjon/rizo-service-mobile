import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'transfer_sheets.dart';

/// What is on this warehouse's shelves, what is coming and what is already promised to others.
class StockTab extends StatefulWidget {
  const StockTab({super.key, required this.warehouseId, required this.canAct, required this.canAsk, required this.onChanged});
  final String warehouseId;
  final bool canAct;
  final bool canAsk;
  final VoidCallback onChanged;
  @override
  State<StockTab> createState() => _StockTabState();
}

class _StockTabState extends State<StockTab> {
  List<WarehouseStockItem> items = [];
  Object? error;
  bool loading = true;
  bool lowOnly = false;
  bool stockedOnly = true;
  final _q = TextEditingController();

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => loading = items.isEmpty);
    try {
      final r = await _api.get('/api/staff/warehouses/${widget.warehouseId}/stock', query: {if (_q.text.trim().isNotEmpty) 'q': _q.text.trim(), if (lowOnly) 'low': '1', if (stockedOnly) 'stocked': '1'});
      if (mounted) {
        setState(() {
          items = asList(asMap(r)['items']).map((e) => WarehouseStockItem(asMap(e))).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit(WarehouseStockItem item, {required bool count}) async {
    final controller = TextEditingController(text: count ? '${item.quantity}' : (item.minQuantity?.toString() ?? ''));
    final note = TextEditingController();
    final locale = Translator.I.locale;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sheet.tr(count ? 'warehouse.countTitle' : 'warehouse.minTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(item.part.localized(locale), style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Labeled(
                sheet.tr(count ? 'warehouse.countedQty' : 'warehouse.minQty'),
                hint: count ? sheet.tr('warehouse.countHint', params: {'count': item.quantity}) : sheet.tr('warehouse.minHint'),
                child: TextField(controller: controller, keyboardType: TextInputType.number),
              ),
              if (count) Labeled(sheet.tr('payments.note'), child: TextField(controller: note, maxLength: 200)),
              SizedBox(
                width: double.infinity,
                child: BusyButton(
                  label: sheet.tr('common.save'),
                  onPressed: () async {
                    final text = controller.text.trim();
                    try {
                      final body = count ? {'quantity': int.tryParse(text) ?? -1, if (note.text.trim().isNotEmpty) 'note': note.text.trim()} : {'minQuantity': text.isEmpty ? null : int.tryParse(text)};
                      if (count && (body['quantity'] as int) < 0) {
                        showSnack(sheet, sheet.tr('warehouse.countedQty'), error: true);
                        return;
                      }
                      await _api.patch('/api/staff/warehouses/${widget.warehouseId}/stock/${item.partId}', body: body);
                      if (sheet.mounted) Navigator.of(sheet).pop(true);
                    } catch (e) {
                      if (sheet.mounted) showSnack(sheet, sheet.errorText(e), error: true);
                    }
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    controller.dispose();
    note.dispose();
    if (saved == true) {
      if (mounted) showSnack(context, tr('warehouse.saved'));
      widget.onChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: TextField(controller: _q, onChanged: (_) => _load(), decoration: InputDecoration(hintText: context.tr('common.search'), prefixIcon: const Icon(Icons.search), isDense: true)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Wrap(spacing: 4, children: [
          FilterChip(
            label: Text(context.tr('warehouse.onlyStocked')),
            selected: stockedOnly,
            onSelected: (v) {
              setState(() => stockedOnly = v);
              _load();
            },
          ),
          FilterChip(
            label: Text(context.tr('warehouse.onlyLow')),
            selected: lowOnly,
            onSelected: (v) {
              setState(() => lowOnly = v);
              _load();
            },
          ),
        ]),
      ),
      Expanded(
        child: loading
            ? const LoadingView()
            : error != null
                ? ErrorView(error: error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: items.isEmpty
                        ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('warehouse.noStockTitle'), body: context.tr('warehouse.noStockBody')))])
                        : ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 24), children: [
                            for (final item in items)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text(item.part.localized(locale), style: const TextStyle(fontWeight: FontWeight.w900))),
                                      Pill('${item.quantity}', color: item.low ? Brand.red : Brand.purple, background: item.low ? Brand.redTint : Brand.purpleTint),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        '${context.tr('warehouse.min')}: ${item.effectiveMin ?? context.tr('common.dash')}',
                                        if (item.onOrder + item.incoming > 0) '${context.tr('warehouse.coming')}: ${item.onOrder + item.incoming}',
                                        if (item.requestedFromHere > 0) '${context.tr('warehouse.promised')}: ${item.requestedFromHere}',
                                      ].join(' · '),
                                      style: TextStyle(color: Brand.muted, fontSize: 13),
                                    ),
                                    if (widget.canAct || widget.canAsk)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Wrap(spacing: 4, children: [
                                          if (widget.canAct) TextButton(onPressed: () => _edit(item, count: true), child: Text(context.tr('warehouse.count'))),
                                          if (widget.canAct) TextButton(onPressed: () => _edit(item, count: false), child: Text(context.tr('warehouse.setMin'))),
                                          if (widget.canAsk)
                                            TextButton(
                                              onPressed: () async {
                                                final sent = await showNewRequestSheet(context, toWarehouseId: widget.warehouseId, partId: item.partId);
                                                if (sent == true) {
                                                  widget.onChanged();
                                                  _load();
                                                }
                                              },
                                              child: Text(context.tr('warehouse.ask')),
                                            ),
                                        ]),
                                      ),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
      ),
    ]);
  }
}
