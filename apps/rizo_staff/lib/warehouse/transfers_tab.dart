import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'source_picker.dart';
import 'transfer_sheets.dart';

/// Requests this warehouse has to answer (`out`) or is waiting for (`in`).
/// [canAct] = the person runs this warehouse (send, refuse); [canReceive] = may confirm that goods arrived.
class TransfersTab extends StatefulWidget {
  const TransfersTab({super.key, required this.warehouseId, required this.direction, required this.canAct, required this.canReceive, required this.canAsk, required this.onChanged});
  final String warehouseId;
  final String direction;
  final bool canAct;
  final bool canReceive;
  final bool canAsk;
  final VoidCallback onChanged;
  @override
  State<TransfersTab> createState() => _TransfersTabState();
}

class _TransfersTabState extends State<TransfersTab> {
  String filter = 'open';
  List<StockTransfer> rows = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;
  bool get _out => widget.direction == 'out';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = rows.isEmpty);
    try {
      final r = await _api.get('/api/staff/transfers', query: {'warehouseId': widget.warehouseId, 'direction': widget.direction, 'status': filter});
      if (mounted) {
        setState(() {
          rows = asList(asMap(r)['transfers']).map((e) => StockTransfer(asMap(e))).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _done(bool? changed) {
    if (changed == true) {
      widget.onChanged();
      _load();
    }
  }

  Future<void> _cancel(StockTransfer t) async {
    try {
      await _api.post('/api/staff/transfers/${t.id}/cancel');
      _done(true);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final me = context.watch<StaffSession>().user!;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Row(children: [
          Expanded(
            child: SegmentedChoice<String>(
              value: filter,
              options: {for (final f in ['open', 'history']) f: context.tr('warehouse.filter.$f')},
              onChanged: (v) {
                setState(() => filter = v);
                _load();
              },
            ),
          ),
          if (!_out && widget.canAsk) ...[
            const SizedBox(width: 8),
            FilledButton.icon(onPressed: () async => _done(await showNewRequestSheet(context, toWarehouseId: widget.warehouseId)), icon: const Icon(Icons.add, size: 18), label: Text(context.tr('warehouse.ask'))),
          ],
        ]),
      ),
      Expanded(
        child: loading
            ? const LoadingView()
            : error != null
                ? ErrorView(error: error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: rows.isEmpty
                        ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr(_out ? 'warehouse.noOutTitle' : 'warehouse.noInTitle'), body: context.tr(_out ? 'warehouse.noOutBody' : 'warehouse.noInBody')))])
                        : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
                            for (final t in rows)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text('${t.part.localized(locale)} × ${t.quantity}', style: const TextStyle(fontWeight: FontWeight.w900))),
                                      transferPill(t.status),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        _out ? '${context.tr('warehouse.to')}: ${t.destination}' : '${context.tr('warehouse.from')}: ${t.fromName}',
                                        if (t.requestedByName != null) '${context.tr('warehouse.askedBy')}: ${t.requestedByName}',
                                        if (t.requestDisplayId != null) '${context.tr('parts.forRequest')}: ${formatRequestId(t.requestDisplayId!)}' else context.tr('parts.forStock'),
                                      ].join(' · '),
                                      style: TextStyle(color: Brand.muted, fontSize: 13),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Row(children: [
                                        Icon(Icons.schedule, size: 15, color: Brand.muted),
                                        const SizedBox(width: 4),
                                        Text(
                                          [formatDateTime(t.createdAt), if (t.etaAt != null) '${context.tr('parts.expected')}: ${formatDate(t.etaAt!)}'].join(' · '),
                                          style: TextStyle(color: Brand.muted, fontSize: 13),
                                        ),
                                        if (t.late) ...[const SizedBox(width: 8), Pill(context.tr('parts.late'), color: Brand.red, background: Brand.redTint)],
                                      ]),
                                    ),
                                    if (t.rejectionReason != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(t.rejectionReason!, style: TextStyle(color: Brand.red, fontSize: 13))),
                                    if (t.status == 'requested' && _out && widget.canAct)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Row(children: [
                                          Expanded(child: FilledButton(onPressed: () async => _done(await showShipSheet(context, t)), child: Text(context.tr('warehouse.ship')))),
                                          const SizedBox(width: 8),
                                          Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Brand.red), onPressed: () async => _done(await showRejectSheet(context, t)), child: Text(context.tr('warehouse.reject')))),
                                        ]),
                                      ),
                                    if (t.status == 'shipped' && !_out && widget.canReceive)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Brand.green), onPressed: () async => _done(await showReceiveSheet(context, t)), child: Text(context.tr('warehouse.receive')))),
                                      ),
                                    if (t.status == 'requested' && (t.requestedById == me.id || (!_out && widget.canAct)))
                                      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _cancel(t), child: Text(context.tr('common.cancel')))),
                                  ]),
                                ),
                              ),
                          ]),
                  ),
      ),
    ]);
  }
}
