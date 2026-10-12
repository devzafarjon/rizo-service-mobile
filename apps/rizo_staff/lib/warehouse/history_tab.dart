import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Every movement on this shelf: receipts, sends, counts, parts used on jobs, parts given to technicians.
class HistoryTab extends StatefulWidget {
  const HistoryTab({super.key, required this.warehouseId});
  final String warehouseId;
  @override
  State<HistoryTab> createState() => _HistoryTabState();
}

class _HistoryTabState extends State<HistoryTab> {
  List<WarehouseMovement> rows = [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = rows.isEmpty);
    try {
      final r = await context.read<StaffSession>().api.get('/api/staff/warehouses/${widget.warehouseId}/movements');
      if (mounted) {
        setState(() {
          rows = asList(asMap(r)['movements']).map((e) => WarehouseMovement(asMap(e))).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
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
          ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('warehouse.noHistoryTitle'), body: context.tr('warehouse.noHistoryBody')))])
          : ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
              for (final m in rows)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(m.part?.localized(locale) ?? context.tr('common.dash'), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(
                      [
                        context.tr('warehouse.move.${m.kind}', def: m.kind),
                        if (m.technicianName != null) m.technicianName!,
                        if (m.createdByName != null) m.createdByName!,
                        formatDateTime(m.createdAt),
                        if (m.note != null) m.note!,
                      ].join(' · '),
                    ),
                    trailing: Text(m.quantity > 0 ? '+${m.quantity}' : '${m.quantity}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: m.quantity < 0 ? Brand.red : Brand.green)),
                  ),
                ),
            ]),
    );
  }
}
