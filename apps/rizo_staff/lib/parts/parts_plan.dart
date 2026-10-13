import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../admin/request_detail_screen.dart';
import 'parts_orders.dart';

/// What to buy next, grouped by supplier: tick the lines, change the quantities, then create the orders,
/// mark them as placed, or copy the message for the supplier.
class RecommendationsTab extends StatefulWidget {
  const RecommendationsTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<RecommendationsTab> createState() => _RecommendationsTabState();
}

class _RecommendationsTabState extends State<RecommendationsTab> {
  List<RecommendationGroup> groups = [];
  List<SupplierInfo> suppliers = [];
  final Map<String, int> quantities = {};
  final Set<String> skipped = {};
  String? chosenSupplier;
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = groups.isEmpty);
    try {
      final r = asMap(await _api.get('/api/staff/part-orders/recommendations'));
      final s = asMap(await _api.get('/api/staff/suppliers'));
      if (!mounted) return;
      setState(() {
        groups = asList(r['groups']).map((e) => RecommendationGroup(asMap(e))).toList();
        suppliers = asList(s['suppliers']).map((e) => SupplierInfo(asMap(e))).where((e) => e.isActive).toList();
        quantities
          ..clear()
          ..addEntries([for (final g in groups) for (final i in g.items) MapEntry(i.partId, i.recommended)]);
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Iterable<RecommendationItem> _selected(RecommendationGroup g) => g.items.where((i) => !skipped.contains(i.partId));

  String _message(RecommendationGroup g) {
    final locale = Translator.I.locale;
    final lines = _selected(g).map((i) => '• ${i.part.localized(locale)} — ${tr('parts.rec.pieces', count: quantities[i.partId] ?? i.recommended)}');
    return [tr('parts.rec.messageHead'), ...lines, tr('parts.rec.messageTail')].join('\n');
  }

  Future<void> _order(RecommendationGroup g, bool markOrdered) async {
    final items = _selected(g).map((i) => {'sparePartId': i.partId, 'quantity': (quantities[i.partId] ?? i.recommended).clamp(1, 9999)}).toList();
    if (items.isEmpty) return;
    try {
      await _api.post('/api/staff/part-orders/bulk', body: {'items': items, 'supplierId': g.supplier?.id ?? chosenSupplier, 'markOrdered': markOrdered});
      if (!mounted) return;
      showSnack(context, markOrdered ? tr('parts.rec.placed') : tr('parts.orderCreated'));
      widget.onChanged();
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  Color _reasonColor(String reason) => switch (reason) { 'waiting' => Brand.red, 'low' => Brand.orangeText, _ => Brand.purple };

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    if (loading) return const LoadingView();
    if (error != null) return ErrorView(error: error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: groups.isEmpty
          ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('parts.rec.emptyTitle'), body: context.tr('parts.rec.emptyBody')))])
          : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
              Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('parts.rec.intro'), style: TextStyle(color: Brand.muted, fontSize: 13))),
              for (final g in groups)
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(g.supplier?.name ?? context.tr('parts.rec.noSupplier'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                      if (g.supplier != null) ...[
                        const SizedBox(height: 2),
                        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          if (g.supplier!.phone != null) PhoneLink(g.supplier!.phone!),
                          if (g.supplier!.telegram != null) Text(g.supplier!.telegram!, style: TextStyle(color: Brand.muted, fontSize: 13)),
                          Text(context.tr('parts.leadDays', count: g.supplier!.leadTimeDays), style: TextStyle(color: Brand.muted, fontSize: 13)),
                        ]),
                      ] else
                        DropdownButton<String?>(
                          value: chosenSupplier,
                          isExpanded: true,
                          hint: Text(context.tr('parts.rec.chooseSupplier')),
                          items: [for (final s in suppliers) DropdownMenuItem<String?>(value: s.id, child: Text(s.name))],
                          onChanged: (v) => setState(() => chosenSupplier = v),
                        ),
                      const SizedBox(height: 8),
                      for (final i in g.items)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Checkbox(value: !skipped.contains(i.partId), onChanged: (v) => setState(() => v == true ? skipped.remove(i.partId) : skipped.add(i.partId))),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(i.part.localized(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
                                Text(
                                  [
                                    '${context.tr('parts.rec.stock')} ${i.stockQuantity}/${i.lowStockThreshold}',
                                    if (i.onOrder > 0) '${context.tr('parts.rec.onOrder')} ${i.onOrder}',
                                    if (i.waitingRequests > 0) context.tr('parts.rec.waitingJobs', count: i.waitingRequests),
                                    if (i.avgDaily > 0) context.tr('parts.rec.usage', params: {'count': i.avgDaily}),
                                    if (i.daysCover != null) context.tr('parts.rec.cover', count: i.daysCover),
                                  ].join(' · '),
                                  style: TextStyle(color: Brand.muted, fontSize: 12),
                                ),
                                const SizedBox(height: 4),
                                Wrap(spacing: 6, children: [for (final r in i.reasons) Pill(context.tr('parts.rec.reason.$r'), color: _reasonColor(r))]),
                              ]),
                            ),
                            Column(children: [
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => quantities[i.partId] = (quantities[i.partId] ?? i.recommended) + 1)),
                              Text('${quantities[i.partId] ?? i.recommended}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              IconButton(visualDensity: VisualDensity.compact, icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => quantities[i.partId] = ((quantities[i.partId] ?? i.recommended) - 1).clamp(1, 9999))),
                            ]),
                          ]),
                        ),
                      const Divider(),
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: _selected(g).isEmpty ? null : () => copyText(context, _message(g)), icon: const Icon(Icons.copy, size: 16), label: Text(context.tr('parts.rec.copy')))),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(child: BusyButton(label: context.tr('parts.rec.create'), outlined: true, enabled: _selected(g).isNotEmpty, onPressed: () => _order(g, false))),
                        const SizedBox(width: 8),
                        Expanded(child: BusyButton(label: context.tr('parts.rec.place'), enabled: _selected(g).isNotEmpty, onPressed: () => _order(g, true))),
                      ]),
                    ]),
                  ),
                ),
            ]),
    );
  }
}

/// Jobs held up by a part: what they need, what is on the way, and which have nothing ordered.
class WaitingTab extends StatefulWidget {
  const WaitingTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<WaitingTab> createState() => _WaitingTabState();
}

class _WaitingTabState extends State<WaitingTab> {
  List<WaitingRequest> requests = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = requests.isEmpty);
    try {
      final r = asMap(await _api.get('/api/staff/part-orders/waiting'));
      if (mounted) {
        setState(() {
          requests = asList(r['requests']).map((e) => WaitingRequest(asMap(e))).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _order(WaitingRequest request, {String? partId, int quantity = 1}) async {
    final saved = await showOrderSheet(context, sparePartId: partId, quantity: quantity, serviceRequestId: request.id);
    if (saved == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final user = context.watch<StaffSession>().user!;
    if (loading) return const LoadingView();
    if (error != null) return ErrorView(error: error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: requests.isEmpty
          ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('parts.waiting.emptyTitle'), body: context.tr('parts.waiting.emptyBody')))])
          : ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
              for (final r in requests)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: r.noOrder ? Brand.red : (r.late ? Brand.orangeText : Colors.transparent), width: r.noOrder || r.late ? 1.5 : 0)),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    // The warehouse has no job screen; the others open the request.
                    onTap: user.isWarehouse ? null : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: r.id))),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(formatRequestId(r.displayId), style: TextStyle(fontWeight: FontWeight.w900, color: Brand.purple))),
                          Pill(r.waitingDays == 0 ? context.tr('parts.waiting.today') : context.tr('parts.waiting.days', count: r.waitingDays)),
                        ]),
                        const SizedBox(height: 2),
                        Text('${r.customerName} · ${r.product.localized(locale)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          PhoneLink(r.customerPhone),
                          if (r.technicianName != null) Text('${context.tr('parts.waiting.technician')}: ${r.technicianName}', style: TextStyle(color: Brand.muted, fontSize: 13)),
                        ]),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 4, children: [
                          if (r.noOrder) Pill(context.tr('parts.waiting.noOrder'), color: Brand.red),
                          if (r.late) Pill(context.tr('parts.late'), color: Brand.orangeText),
                          if (r.isOverdue) Pill(context.tr('parts.waiting.overdue'), color: Brand.red),
                          if (r.expectedAt != null) Pill(context.tr('parts.waiting.expected', params: {'date': formatDate(r.expectedAt!)})),
                        ]),
                        const SizedBox(height: 6),
                        if (r.items.isEmpty)
                          Row(children: [
                            Expanded(child: Text(context.tr('parts.waiting.noItems'), style: TextStyle(color: Brand.red, fontSize: 13, fontWeight: FontWeight.w700))),
                            FilledButton(onPressed: () => _order(r), child: Text(context.tr('parts.order'))),
                          ])
                        else
                          for (final item in r.items)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(children: [
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(item.part.localized(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
                                    Text('${context.tr('parts.waiting.needed')} ${item.needed} · ${context.tr('parts.waiting.inStock')} ${item.inStock} · ${context.tr('parts.waiting.onOrder')} ${item.ordered}', style: TextStyle(color: Brand.muted, fontSize: 12)),
                                    for (final o in item.orders)
                                      Text(
                                        '${o.supplier ?? context.tr('common.dash')} · ${context.tr('parts.status.${o.status}')}${o.expectedAt != null ? ' · ${formatDate(o.expectedAt!)}' : ''}${o.late ? ' · ${context.tr('parts.late')}' : ''}',
                                        style: TextStyle(color: o.late ? Brand.red : Brand.muted, fontSize: 12),
                                      ),
                                  ]),
                                ),
                                if (item.needsOrder) FilledButton(onPressed: () => _order(r, partId: item.partId, quantity: item.uncovered), child: Text(context.tr('parts.order'))),
                              ]),
                            ),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}
