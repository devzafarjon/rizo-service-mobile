import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../warehouse/source_picker.dart';
import '../warehouse/transfer_sheets.dart';

/// The parts the technician carries, and the parts asked from a warehouse for the van. On a job they are used before the warehouse stock.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Json> rows = [];
  List<StockTransfer> asked = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get('/api/staff/my-jobs/stock');
      List<StockTransfer> transfers = asked;
      try {
        transfers = asList(asMap(await _api.get('/api/staff/my-jobs/transfers'))['transfers']).map((e) => StockTransfer(asMap(e))).toList();
      } catch (_) {}
      if (mounted) {
        setState(() {
          rows = asList(asMap(r)['stock']);
          asked = transfers;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _ask() async {
    final sent = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => const _VanRequestSheet());
    if (sent == true) _load();
  }

  Future<void> _receive(StockTransfer t) async {
    final done = await showReceiveSheet(context, t, mine: true);
    if (done == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('techStock.mineTitle'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _ask, icon: const Icon(Icons.add), label: Text(context.tr('warehouse.vanRequest'))),
      body: loading
          ? const LoadingView()
          : error != null && rows.isEmpty
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 14, 14, 96), children: [
                    if (rows.isEmpty)
                      SizedBox(height: 260, child: EmptyView(title: context.tr('techStock.mineEmpty'), body: context.tr('techStock.mineEmptyBody')))
                    else ...[
                      Text(context.tr('techStock.mineIntro'), style: TextStyle(color: Brand.muted)),
                      const SizedBox(height: 12),
                      for (final row in rows)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(Named.fromJson(row).localized(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
                            trailing: Pill('${row['quantity']}', color: Brand.purple, background: Brand.purpleTint),
                          ),
                        ),
                    ],
                    if (asked.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      Text(context.tr('warehouse.myRequests'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 8),
                      for (final t in asked)
                        Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text('${t.part.localized(locale)} × ${t.quantity}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text([t.fromName, if (t.etaAt != null) formatDate(t.etaAt!), if (t.rejectionReason != null) t.rejectionReason!].join(' · '), style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                                ]),
                              ),
                              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                                transferPill(t.status),
                                if (t.status == 'shipped') TextButton(onPressed: () => _receive(t), child: Text(context.tr('warehouse.receive'))),
                              ]),
                            ]),
                          ),
                        ),
                    ],
                  ]),
                ),
    );
  }
}

/// Top up the van: pick a part, see where it can come from, and ask for it to be sent to me.
class _VanRequestSheet extends StatefulWidget {
  const _VanRequestSheet();
  @override
  State<_VanRequestSheet> createState() => _VanRequestSheetState();
}

class _VanRequestSheetState extends State<_VanRequestSheet> {
  List<Json> parts = [];
  List<SourceOption> options = [];
  String? partId;
  String choice = '';
  bool loading = true;
  bool loadingSources = false;
  Object? error;
  final _q = TextEditingController();
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();

  ApiClient get _api => context.read<StaffSession>().api;
  int get _count => (int.tryParse(_qty.text.trim()) ?? 1).clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _loadParts();
  }

  @override
  void dispose() {
    _q.dispose();
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadParts() async {
    try {
      final r = asMap(await _api.get('/api/staff/my-jobs/parts', query: {if (_q.text.trim().isNotEmpty) 'q': _q.text.trim()}));
      if (mounted) {
        setState(() {
          parts = asList(r['parts']).map(asMap).toList();
          if (!parts.any((p) => p['id'] == partId)) partId = null;
          error = null;
        });
      }
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
      final r = asMap(await _api.get('/api/staff/my-jobs/part-sources', query: {'partId': partId, 'quantity': '$_count'}));
      final list = asList(r['options']).map((e) => SourceOption(asMap(e))).where((o) => !o.isSupplier).toList();
      if (!mounted) return;
      setState(() {
        options = list;
        choice = list.where((o) => o.recommended || o.selectable).map((o) => o.key).firstOrNull ?? '';
      });
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => loadingSources = false);
    }
  }

  Future<void> _send() async {
    if (partId == null || choice.isEmpty) return;
    try {
      await _api.post('/api/staff/my-jobs/stock/requests', body: {'sparePartId': partId, 'quantity': _count, 'fromWarehouseId': choice.replaceFirst('wh:', ''), if (_note.text.trim().isNotEmpty) 'note': _note.text.trim()});
      if (!mounted) return;
      showSnack(context, tr('warehouse.requestSent'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: loading
              ? const SizedBox(height: 200, child: LoadingView())
              : error != null
                  ? ErrorView(error: error!, onRetry: _loadParts)
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr('warehouse.vanRequestTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Labeled(context.tr('catalog.part'), child: TextField(controller: _q, onChanged: (_) => _loadParts(), decoration: InputDecoration(hintText: context.tr('common.search'), prefixIcon: const Icon(Icons.search), isDense: true))),
                      DropdownButtonFormField<String>(
                        initialValue: partId,
                        isExpanded: true,
                        hint: Text(context.tr('parts.selectPart')),
                        items: [for (final p in parts) DropdownMenuItem(value: p['id'].toString(), child: Text('${Named.fromJson(p).localized(locale)} · ${p['stockQuantity']}', overflow: TextOverflow.ellipsis))],
                        onChanged: (v) {
                          setState(() => partId = v);
                          _sources();
                        },
                      ),
                      const SizedBox(height: 14),
                      Labeled(context.tr('common.qty'), child: TextField(controller: _qty, keyboardType: TextInputType.number, onSubmitted: (_) => _sources(), onEditingComplete: _sources)),
                      if (partId != null) ...[
                        Text(context.tr('warehouse.source.title').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.subtle)),
                        const SizedBox(height: 8),
                        if (loadingSources) const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator())) else SourcePicker(options: options, value: choice, onChanged: (o) => setState(() => choice = o.key)),
                      ],
                      Labeled(context.tr('payments.note'), hint: context.tr('warehouse.vanHint'), child: TextField(controller: _note, maxLength: 200)),
                      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('warehouse.ask'), enabled: partId != null && choice.isNotEmpty, onPressed: _send)),
                    ]),
        ),
      ),
    );
  }
}
