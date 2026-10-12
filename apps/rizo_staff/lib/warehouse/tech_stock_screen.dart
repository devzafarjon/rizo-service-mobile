import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// The parts each technician carries. The warehouse hands parts out and takes unused ones back. Same as the website's technician stock.
class TechStockScreen extends StatefulWidget {
  const TechStockScreen({super.key, this.bell});
  final Widget? bell;
  @override
  State<TechStockScreen> createState() => _TechStockScreenState();
}

class _TechStockScreenState extends State<TechStockScreen> {
  List<Json> technicians = [];
  List<Json> movements = [];
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
      final o = asMap(await _api.get('/api/staff/tech-stock'));
      final m = asMap(await _api.get('/api/staff/tech-stock/movements'));
      if (mounted) {
        setState(() {
          technicians = asList(o['technicians']).map(asMap).toList();
          movements = asList(m['movements']).map(asMap).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _move({required bool issue, String? technicianId}) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _MoveSheet(issue: issue, technicians: technicians, technicianId: technicianId));
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('techStock.title')), actions: [?widget.bell, IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _move(issue: true), icon: const Icon(Icons.add), label: Text(context.tr('techStock.issue'))),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 96), children: [
                    Text(context.tr('techStock.intro'), style: TextStyle(color: Brand.muted)),
                    const SizedBox(height: 10),
                    if (technicians.isEmpty) SizedBox(height: 200, child: EmptyView(title: context.tr('techStock.noTechnicians'))),
                    for (final tech in technicians)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(tech['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  Text(context.tr('techStock.carrying', params: {'count': asInt(tech['total'])}), style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                                ]),
                              ),
                              TextButton(onPressed: asList(tech['items']).isEmpty ? null : () => _move(issue: false, technicianId: tech['id'].toString()), child: Text(context.tr('techStock.takeBack'))),
                            ]),
                            if (asList(tech['items']).isEmpty)
                              Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('techStock.nothing'), style: TextStyle(color: Brand.muted)))
                            else
                              for (final item in asList(tech['items']).map(asMap))
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Row(children: [
                                    Expanded(child: Text(Named.fromJson(item).localized(locale), style: const TextStyle(fontWeight: FontWeight.w700))),
                                    Pill('${item['quantity']}', color: Brand.purple, background: Brand.purpleTint),
                                  ]),
                                ),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Text(context.tr('techStock.recent').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.subtle)),
                    const SizedBox(height: 6),
                    if (movements.isEmpty)
                      Text(context.tr('techStock.noMoves'), style: TextStyle(color: Brand.muted))
                    else
                      for (final m in movements)
                        Card(
                          margin: const EdgeInsets.only(bottom: 6),
                          child: ListTile(
                            dense: true,
                            title: Text('${m['part'] is Map ? Named.fromJson(m['part']).localized(locale) : context.tr('common.dash')} × ${m['quantity']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text([context.tr('techStock.kind.${m['kind']}', def: '${m['kind']}'), if (m['technicianName'] != null) '${m['technicianName']}', if (m['createdByName'] != null) '${m['createdByName']}', formatDateTime(DateTime.tryParse('${m['createdAt']}'))].join(' · ')),
                          ),
                        ),
                  ]),
                ),
    );
  }
}

class _MoveSheet extends StatefulWidget {
  const _MoveSheet({required this.issue, required this.technicians, this.technicianId});
  final bool issue;
  final List<Json> technicians;
  final String? technicianId;
  @override
  State<_MoveSheet> createState() => _MoveSheetState();
}

class _MoveSheetState extends State<_MoveSheet> {
  List<Json> parts = [];
  late String? technicianId = widget.technicianId ?? widget.technicians.firstOrNull?['id']?.toString();
  String? partId;
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  bool loading = true;
  Object? error;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
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
      final r = asMap(await _api.get('/api/staff/catalog/parts'));
      if (mounted) setState(() => parts = asList(r['parts']).map(asMap).toList());
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// A return can only be of parts the technician holds.
  List<Json> get _choices {
    if (widget.issue) return parts;
    final tech = widget.technicians.where((t) => t['id'].toString() == technicianId).firstOrNull;
    final held = {for (final item in asList(tech?['items']).map(asMap)) item['sparePartId'].toString()};
    return parts.where((p) => held.contains(p['id'].toString())).toList();
  }

  Future<void> _save() async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    if (technicianId == null || partId == null || qty < 1) {
      showSnack(context, tr('parts.selectPart'), error: true);
      return;
    }
    try {
      await _api.post('/api/staff/tech-stock/${widget.issue ? 'issue' : 'return'}', body: {'technicianId': technicianId, 'sparePartId': partId, 'quantity': qty, if (_note.text.trim().isNotEmpty) 'note': _note.text.trim()});
      if (!mounted) return;
      showSnack(context, tr('techStock.saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final choices = _choices;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: loading
              ? const SizedBox(height: 180, child: LoadingView())
              : error != null
                  ? ErrorView(error: error!, onRetry: _load)
                  : Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(context.tr(widget.issue ? 'techStock.issue' : 'techStock.takeBack'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 14),
                      Labeled(
                        context.tr('techStock.technician'),
                        child: DropdownButtonFormField<String>(
                          initialValue: technicianId,
                          isExpanded: true,
                          items: [for (final t in widget.technicians) DropdownMenuItem(value: t['id'].toString(), child: Text(t['name'].toString()))],
                          onChanged: (v) => setState(() {
                            technicianId = v;
                            partId = null;
                          }),
                        ),
                      ),
                      Labeled(
                        context.tr('catalog.part'),
                        child: DropdownButtonFormField<String>(
                          initialValue: choices.any((p) => p['id'].toString() == partId) ? partId : null,
                          isExpanded: true,
                          hint: Text(context.tr('common.select')),
                          items: [for (final p in choices) DropdownMenuItem(value: p['id'].toString(), child: Text('${Named.fromJson(p).localized(locale)} · ${context.tr('techStock.inWarehouse', params: {'count': asInt(p['stockQuantity'])})}', overflow: TextOverflow.ellipsis))],
                          onChanged: (v) => setState(() => partId = v),
                        ),
                      ),
                      Labeled(context.tr('common.qty'), child: TextField(controller: _qty, keyboardType: TextInputType.number)),
                      Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 200)),
                      SizedBox(width: double.infinity, child: BusyButton(label: context.tr('common.save'), onPressed: _save)),
                    ]),
        ),
      ),
    );
  }
}
