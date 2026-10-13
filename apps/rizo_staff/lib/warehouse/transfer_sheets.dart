import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'source_picker.dart';

String _ymd(DateTime d) => isoDate(d);

Future<T?> _sheet<T>(BuildContext context, Widget Function(BuildContext) builder) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true, showDragHandle: true, builder: builder);

Widget _frame(BuildContext sheet, {required String title, required List<Widget> children}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(sheet).viewInsets.bottom),
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          ...children,
        ]),
      ),
    ),
  );
}

/// The source warehouse sends the goods (all of them or only some) and may promise a date. Returns true when sent.
Future<bool?> showShipSheet(BuildContext context, StockTransfer transfer) => _sheet<bool>(context, (_) => _ShipSheet(transfer: transfer));

class _ShipSheet extends StatefulWidget {
  const _ShipSheet({required this.transfer});
  final StockTransfer transfer;
  @override
  State<_ShipSheet> createState() => _ShipSheetState();
}

class _ShipSheetState extends State<_ShipSheet> {
  late final _qty = TextEditingController(text: '${widget.transfer.quantity}');
  DateTime? eta;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (qty < 1 || qty > widget.transfer.quantity) {
      showSnack(context, tr('errors.transferQuantityInvalid'), error: true);
      return;
    }
    try {
      await context.read<StaffSession>().api.post('/api/staff/transfers/${widget.transfer.id}/ship', body: {'quantity': qty, 'etaAt': eta == null ? null : _ymd(eta!)});
      if (!mounted) return;
      showSnack(context, tr('warehouse.shipped'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final locale = context.watch<Translator>().locale;
    return _frame(context, title: context.tr('warehouse.shipTitle'), children: [
      Text('${t.part.localized(locale)} · ${context.tr('warehouse.asked', params: {'count': t.quantity})} → ${t.destination}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Labeled(context.tr('warehouse.sendQty'), hint: context.tr('warehouse.sendQtyHint'), child: TextField(controller: _qty, keyboardType: TextInputType.number)),
      Labeled(
        context.tr('warehouse.etaDate'),
        hint: context.tr('warehouse.etaHint'),
        child: OutlinedButton.icon(
          onPressed: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(context: context, initialDate: eta ?? now, firstDate: now.subtract(const Duration(days: 7)), lastDate: now.add(const Duration(days: 120)));
            if (picked != null) setState(() => eta = picked);
          },
          icon: const Icon(Icons.event, size: 18),
          label: Text(eta == null ? context.tr('common.dash') : formatDate(_ymd(eta!))),
        ),
      ),
      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('warehouse.ship'), onPressed: _send)),
    ]);
  }
}

/// The goods are in hand. A smaller quantity can be entered; the rest goes back to the sender. [mine] = a technician confirming the van.
Future<bool?> showReceiveSheet(BuildContext context, StockTransfer transfer, {bool mine = false}) => _sheet<bool>(context, (_) => _ReceiveSheet(transfer: transfer, mine: mine));

class _ReceiveSheet extends StatefulWidget {
  const _ReceiveSheet({required this.transfer, required this.mine});
  final StockTransfer transfer;
  final bool mine;
  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  late final _qty = TextEditingController(text: '${widget.transfer.quantity}');

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  Future<void> _receive() async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (qty < 1 || qty > widget.transfer.quantity) {
      showSnack(context, tr('errors.transferQuantityInvalid'), error: true);
      return;
    }
    final path = widget.mine ? '/api/staff/my-jobs/transfers/${widget.transfer.id}/receive' : '/api/staff/transfers/${widget.transfer.id}/receive';
    try {
      await context.read<StaffSession>().api.post(path, body: {'quantity': qty});
      if (!mounted) return;
      showSnack(context, tr('warehouse.received'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final locale = context.watch<Translator>().locale;
    return _frame(context, title: context.tr('warehouse.receiveTitle'), children: [
      Text('${t.part.localized(locale)} · ${context.tr('warehouse.sentQty', params: {'count': t.quantity})} · ${t.fromName}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Labeled(context.tr('warehouse.receivedQty'), hint: context.tr('warehouse.receivedQtyHint'), child: TextField(controller: _qty, keyboardType: TextInputType.number)),
      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('warehouse.receive'), onPressed: _receive)),
    ]);
  }
}

/// Refuse a request with a reason (shown to who asked; a job-linked request moves on to the next source).
Future<bool?> showRejectSheet(BuildContext context, StockTransfer transfer) => _sheet<bool>(context, (_) => _RejectSheet(transfer: transfer));

class _RejectSheet extends StatefulWidget {
  const _RejectSheet({required this.transfer});
  final StockTransfer transfer;
  @override
  State<_RejectSheet> createState() => _RejectSheetState();
}

class _RejectSheetState extends State<_RejectSheet> {
  final _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _reject() async {
    if (_reason.text.trim().isEmpty) {
      showSnack(context, tr('warehouse.rejectReason'), error: true);
      return;
    }
    try {
      await context.read<StaffSession>().api.post('/api/staff/transfers/${widget.transfer.id}/reject', body: {'reason': _reason.text.trim()});
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.transfer;
    final locale = context.watch<Translator>().locale;
    return _frame(context, title: context.tr('warehouse.rejectTitle'), children: [
      Text('${t.part.localized(locale)} × ${t.quantity} · ${t.requestedByName ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Labeled(context.tr('warehouse.rejectReason'), hint: context.tr('warehouse.rejectHint'), child: TextField(controller: _reason, maxLength: 200)),
      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('warehouse.reject'), danger: true, onPressed: _reject)),
    ]);
  }
}

/// Ask for a part for a warehouse: pick the part and quantity, see where it can come from and how fast, choose.
Future<bool?> showNewRequestSheet(BuildContext context, {required String toWarehouseId, String? partId}) => _sheet<bool>(context, (_) => _NewRequestSheet(toWarehouseId: toWarehouseId, partId: partId));

class _NewRequestSheet extends StatefulWidget {
  const _NewRequestSheet({required this.toWarehouseId, this.partId});
  final String toWarehouseId;
  final String? partId;
  @override
  State<_NewRequestSheet> createState() => _NewRequestSheetState();
}

class _NewRequestSheetState extends State<_NewRequestSheet> {
  List<Json> parts = [];
  List<SourceOption> options = [];
  String? partId;
  String choice = '';
  bool loading = true;
  bool loadingSources = false;
  Object? error;
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();

  ApiClient get _api => context.read<StaffSession>().api;
  int get _count => (int.tryParse(_qty.text.trim()) ?? 1).clamp(1, 100000);

  @override
  void initState() {
    super.initState();
    partId = widget.partId;
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
      if (mounted) setState(() => parts = asList(p['parts']).map(asMap).toList());
      if (partId != null) await _sources();
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _sources() async {
    if (partId == null) return;
    setState(() => loadingSources = true);
    try {
      final r = asMap(await _api.get('/api/staff/warehouses/sources', query: {'partId': partId, 'quantity': '$_count', 'toWarehouseId': widget.toWarehouseId}));
      final list = asList(r['options']).map((e) => SourceOption(asMap(e))).toList();
      if (!mounted) return;
      setState(() {
        options = list;
        choice = list.where((o) => o.recommended).map((o) => o.key).firstOrNull ?? '';
      });
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => loadingSources = false);
    }
  }

  Future<void> _send() async {
    if (partId == null || choice.isEmpty) return;
    try {
      if (choice == 'supplier') {
        await _api.post('/api/staff/part-orders', body: {'sparePartId': partId, 'quantity': _count, 'warehouseId': widget.toWarehouseId, if (_note.text.trim().isNotEmpty) 'note': _note.text.trim()});
      } else {
        await _api.post('/api/staff/transfers', body: {
          'sparePartId': partId,
          'quantity': _count,
          'fromWarehouseId': choice.replaceFirst('wh:', ''),
          'toWarehouseId': widget.toWarehouseId,
          if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
        });
      }
      if (!mounted) return;
      showSnack(context, tr(choice == 'supplier' ? 'parts.orderCreated' : 'warehouse.requestSent'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    if (loading) return const SizedBox(height: 220, child: LoadingView());
    if (error != null) return SizedBox(height: 260, child: ErrorView(error: error!, onRetry: _load));
    return _frame(context, title: context.tr('warehouse.newRequest'), children: [
      Labeled(
        context.tr('catalog.part'),
        child: DropdownButtonFormField<String>(
          initialValue: partId,
          isExpanded: true,
          hint: Text(context.tr('parts.selectPart')),
          items: [for (final p in parts) DropdownMenuItem(value: p['id'].toString(), child: Text('${Named.fromJson(p).localized(locale)} · ${p['stockQuantity']}', overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            setState(() => partId = v);
            _sources();
          },
        ),
      ),
      Labeled(context.tr('common.qty'), child: TextField(controller: _qty, keyboardType: TextInputType.number, onSubmitted: (_) => _sources(), onEditingComplete: _sources)),
      if (partId != null) ...[
        Text(context.tr('warehouse.source.title').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.subtle)),
        const SizedBox(height: 8),
        if (loadingSources) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())) else SourcePicker(options: options, value: choice, onChanged: (o) => setState(() => choice = o.key)),
      ],
      Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 200)),
      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('warehouse.ask'), enabled: partId != null && choice.isNotEmpty, onPressed: _send)),
    ]);
  }
}
