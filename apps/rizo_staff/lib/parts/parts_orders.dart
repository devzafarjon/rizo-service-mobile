import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rizo_core/rizo_core.dart';

/// A new order: part, quantity, supplier (its delivery time gives the expected date) and optionally the job it is for.
/// Returns true when an order was created.
Future<bool?> showOrderSheet(BuildContext context, {String? sparePartId, int quantity = 1, String? serviceRequestId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _OrderSheet(sparePartId: sparePartId, quantity: quantity, serviceRequestId: serviceRequestId),
  );
}

class _OrderSheet extends StatefulWidget {
  const _OrderSheet({this.sparePartId, this.quantity = 1, this.serviceRequestId});
  final String? sparePartId;
  final int quantity;
  final String? serviceRequestId;
  @override
  State<_OrderSheet> createState() => _OrderSheetState();
}

class _OrderSheetState extends State<_OrderSheet> {
  List<Json> parts = [];
  List<SupplierInfo> suppliers = [];
  String? partId;
  String? supplierId;
  DateTime? expected;
  late final TextEditingController _qty = TextEditingController(text: '${widget.quantity}');
  final _note = TextEditingController();
  bool loading = true;
  Object? error;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    partId = widget.sparePartId;
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = asMap(await _api.get('/api/staff/catalog/parts'));
      final s = asMap(await _api.get('/api/staff/suppliers'));
      if (mounted) {
        setState(() {
          parts = asList(p['parts']).map(asMap).toList();
          suppliers = asList(s['suppliers']).map((e) => SupplierInfo(asMap(e))).where((e) => e.isActive).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: expected ?? now, firstDate: now.subtract(const Duration(days: 30)), lastDate: now.add(const Duration(days: 365)));
    if (picked != null) setState(() => expected = picked);
  }

  String _ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _save() async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (partId == null || qty < 1) {
      showSnack(context, tr('parts.selectPart'), error: true);
      return;
    }
    try {
      await _api.post('/api/staff/part-orders', body: {
        'sparePartId': partId,
        'quantity': qty,
        if (supplierId != null) 'supplierId': supplierId,
        if (expected != null) 'expectedAt': _ymd(expected!),
        if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        if (widget.serviceRequestId != null) 'serviceRequestId': widget.serviceRequestId,
      });
      if (!mounted) return;
      showSnack(context, tr('parts.orderCreated'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final usual = parts.where((p) => p['id'] == partId).map((p) => p['supplierId']).firstOrNull;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: loading
              ? const SizedBox(height: 160, child: LoadingView())
              : error != null
                  ? ErrorView(error: error!, onRetry: _load)
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('parts.newOrder'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Labeled(
                        context.tr('catalog.part'),
                        child: DropdownButtonFormField<String>(
                          initialValue: partId,
                          isExpanded: true,
                          hint: Text(context.tr('parts.selectPart')),
                          items: [
                            for (final p in parts)
                              DropdownMenuItem(value: p['id'].toString(), child: Text('${Named.fromJson(p).localized(locale)} · ${p['stockQuantity']}', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => partId = v),
                        ),
                      ),
                      Row(children: [
                        Expanded(child: Labeled(context.tr('common.qty'), child: TextField(controller: _qty, keyboardType: TextInputType.number))),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Labeled(
                            context.tr('parts.expected'),
                            child: OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.event, size: 18), label: Text(expected == null ? context.tr('common.dash') : formatDate(_ymd(expected!)))),
                          ),
                        ),
                      ]),
                      Labeled(
                        context.tr('parts.supplier'),
                        hint: context.tr('parts.expectedHint'),
                        child: DropdownButtonFormField<String?>(
                          initialValue: supplierId,
                          isExpanded: true,
                          items: [
                            DropdownMenuItem<String?>(value: null, child: Text(usual != null ? context.tr('parts.usualSupplier') : context.tr('catalog.noSupplier'))),
                            for (final s in suppliers) DropdownMenuItem<String?>(value: s.id, child: Text('${s.name} · ${context.tr('parts.leadDays', count: s.leadTimeDays)}', overflow: TextOverflow.ellipsis)),
                          ],
                          onChanged: (v) => setState(() => supplierId = v),
                        ),
                      ),
                      Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 200)),
                      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('common.save'), onPressed: _save)),
                    ]),
        ),
      ),
    );
  }
}

/// Every order: place it, receive it (all or only what came), cancel it.
class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> {
  String filter = 'open';
  List<PartOrderRow> orders = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = orders.isEmpty);
    try {
      final r = await _api.get('/api/staff/part-orders', query: {if (filter != 'all') 'status': filter});
      if (mounted) {
        setState(() {
          orders = asList(asMap(r)['orders']).map((e) => PartOrderRow(asMap(e))).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _patch(PartOrderRow order, Map<String, Object?> body) async {
    try {
      await _api.patch('/api/staff/part-orders/${order.id}', body: body);
      widget.onChanged();
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  Future<void> _receive(PartOrderRow order) async {
    final controller = TextEditingController(text: '${order.quantity}');
    final locale = Translator.I.locale;
    final qty = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sheet.tr('parts.receiveTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('${order.part.localized(locale)} · ${sheet.tr('parts.orderedQty', count: order.quantity)}', style: TextStyle(color: Brand.muted)),
              const SizedBox(height: 14),
              Labeled(sheet.tr('parts.receivedQty'), hint: sheet.tr('parts.receivedQtyHint'), child: TextField(controller: controller, keyboardType: TextInputType.number)),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Brand.green),
                  onPressed: () => Navigator.of(sheet).pop(int.tryParse(controller.text.trim())),
                  child: Text(sheet.tr('parts.markReceived')),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
    controller.dispose();
    if (qty == null) return;
    await _patch(order, {'status': 'received', 'receivedQuantity': qty});
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final user = context.watch<StaffSession>().user!;
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: SegmentedChoice<String>(value: filter, options: {for (final f in ['open', 'received', 'all']) f: context.tr('parts.filter.$f')}, onChanged: (v) {
        setState(() => filter = v);
        _load();
      })),
      Expanded(
        child: loading
            ? const LoadingView()
            : error != null
                ? ErrorView(error: error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: orders.isEmpty
                        ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('parts.noOrdersTitle'), body: context.tr('parts.noOrdersBody')))])
                        : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 90), children: [
                            for (final o in orders)
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(children: [
                                      Expanded(child: Text('${o.part.localized(locale)} × ${o.quantity}', style: const TextStyle(fontWeight: FontWeight.w900))),
                                      Pill(context.tr('parts.status.${o.status}')),
                                    ]),
                                    const SizedBox(height: 4),
                                    Text(
                                      [
                                        o.supplier ?? context.tr('common.dash'),
                                        o.requestDisplayId != null ? '${context.tr('parts.forRequest')}: ${formatRequestId(o.requestDisplayId!)}' : context.tr('parts.forStock'),
                                      ].join(' · '),
                                      style: TextStyle(color: Brand.muted, fontSize: 13),
                                    ),
                                    if (o.expectedAt != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(children: [
                                          Icon(Icons.event, size: 15, color: Brand.muted),
                                          const SizedBox(width: 4),
                                          Text('${context.tr('parts.expected')}: ${formatDate(o.expectedAt!)}', style: TextStyle(color: Brand.muted, fontSize: 13)),
                                          if (o.late && o.isOpen) ...[const SizedBox(width: 8), Pill(context.tr('parts.late'), color: Brand.red)],
                                        ]),
                                      ),
                                    if (o.isOpen)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Row(children: [
                                          if (o.status == 'requested') ...[
                                            Expanded(child: OutlinedButton(onPressed: () => _patch(o, {'status': 'ordered'}), child: Text(context.tr('parts.markOrdered')))),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(child: FilledButton(onPressed: () => _receive(o), child: Text(context.tr('parts.markReceived')))),
                                          if (user.isAdmin) ...[
                                            const SizedBox(width: 4),
                                            IconButton(tooltip: context.tr('common.cancel'), onPressed: () => _patch(o, {'status': 'cancelled'}), icon: Icon(Icons.close, color: Brand.red)),
                                          ],
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

/// Puts a supplier message on the clipboard.
Future<void> copyText(BuildContext context, String text) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) showSnack(context, tr('parts.rec.copied'));
}
