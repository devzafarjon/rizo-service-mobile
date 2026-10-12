import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Who the parts are bought from; the delivery time gives every order its expected date.
class SuppliersTab extends StatefulWidget {
  const SuppliersTab({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<SuppliersTab> createState() => _SuppliersTabState();
}

class _SuppliersTabState extends State<SuppliersTab> {
  List<SupplierInfo> suppliers = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = suppliers.isEmpty);
    try {
      final r = asMap(await _api.get('/api/staff/suppliers'));
      if (mounted) {
        setState(() {
          suppliers = asList(r['suppliers']).map((e) => SupplierInfo(asMap(e))).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _edit([SupplierInfo? s]) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _SupplierSheet(supplier: s));
    if (saved == true) {
      await _load();
      widget.onChanged();
    }
  }

  Future<void> _toggle(SupplierInfo s) async {
    try {
      await _api.patch('/api/staff/suppliers/${s.id}', body: {'isActive': !s.isActive});
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<StaffSession>().user!;
    final canEdit = user.editsSuppliers;
    if (loading) return const LoadingView();
    if (error != null) return ErrorView(error: error!, onRetry: _load);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(12, 8, 12, 90), children: [
        Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('parts.suppliers.intro'), style: TextStyle(color: Brand.muted, fontSize: 13))),
        if (canEdit) Align(alignment: Alignment.centerLeft, child: FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add), label: Text(context.tr('parts.suppliers.add')))),
        const SizedBox(height: 8),
        if (suppliers.isEmpty) SizedBox(height: 240, child: EmptyView(title: context.tr('parts.suppliers.emptyTitle'), body: context.tr('parts.suppliers.emptyBody'))),
        for (final s in suppliers)
          Opacity(
            opacity: s.isActive ? 1 : 0.6,
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(child: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                    Pill(s.isActive ? context.tr('parts.suppliers.active') : context.tr('parts.suppliers.inactive')),
                  ]),
                  const SizedBox(height: 4),
                  Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    if (s.phone != null) PhoneLink(s.phone!),
                    if (s.telegram != null) Text(s.telegram!, style: TextStyle(color: Brand.muted, fontSize: 13)),
                    Text(context.tr('parts.leadDays', count: s.leadTimeDays), style: TextStyle(color: Brand.muted, fontSize: 13)),
                    Text('${context.tr('parts.suppliers.parts')}: ${s.partsCount}', style: TextStyle(color: Brand.muted, fontSize: 13)),
                  ]),
                  if (s.note != null && s.note!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Text(s.note!, style: TextStyle(color: Brand.faint, fontSize: 12))),
                  if (canEdit)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        TextButton(onPressed: () => _edit(s), child: Text(context.tr('common.edit'))),
                        TextButton(onPressed: () => _toggle(s), child: Text(s.isActive ? context.tr('parts.suppliers.switchOff') : context.tr('parts.suppliers.switchOn'))),
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

class _SupplierSheet extends StatefulWidget {
  const _SupplierSheet({this.supplier});
  final SupplierInfo? supplier;
  @override
  State<_SupplierSheet> createState() => _SupplierSheetState();
}

class _SupplierSheetState extends State<_SupplierSheet> {
  late final _name = TextEditingController(text: widget.supplier?.name ?? '');
  late final _phone = TextEditingController(text: widget.supplier?.phone ?? '');
  late final _telegram = TextEditingController(text: widget.supplier?.telegram ?? '');
  late final _lead = TextEditingController(text: '${widget.supplier?.leadTimeDays ?? 3}');
  late final _note = TextEditingController(text: widget.supplier?.note ?? '');

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void dispose() {
    for (final c in [_name, _phone, _telegram, _lead, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    final body = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'telegram': _telegram.text.trim().isEmpty ? null : _telegram.text.trim(),
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      'leadTimeDays': int.tryParse(_lead.text.trim()) ?? 3,
    };
    try {
      if (widget.supplier == null) {
        await _api.post('/api/staff/suppliers', body: body);
      } else {
        await _api.patch('/api/staff/suppliers/${widget.supplier!.id}', body: body);
      }
      if (!mounted) return;
      showSnack(context, tr('parts.suppliers.saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.supplier == null ? context.tr('parts.suppliers.add') : context.tr('parts.suppliers.edit'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Labeled(context.tr('parts.suppliers.name'), child: TextField(controller: _name, maxLength: 100)),
            Row(children: [
              Expanded(child: Labeled(context.tr('parts.suppliers.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone))),
              const SizedBox(width: 12),
              Expanded(child: Labeled(context.tr('parts.suppliers.telegram'), child: TextField(controller: _telegram))),
            ]),
            Labeled(context.tr('parts.suppliers.lead'), hint: context.tr('parts.suppliers.leadHint'), child: TextField(controller: _lead, keyboardType: TextInputType.number)),
            Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 300)),
            SizedBox(width: double.infinity, child: BusyButton(label: context.tr('common.save'), onPressed: _save)),
          ]),
        ),
      ),
    );
  }
}
