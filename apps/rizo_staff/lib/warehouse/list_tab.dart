import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'source_picker.dart';

/// Admin: all warehouses of the network. Add one, edit it, switch it off, link a branch warehouse to its service centre.
class WarehouseListTab extends StatefulWidget {
  const WarehouseListTab({super.key, required this.warehouses, required this.onOpen, required this.onChanged});
  final List<Warehouse> warehouses;
  final ValueChanged<String> onOpen;
  final VoidCallback onChanged;
  @override
  State<WarehouseListTab> createState() => _WarehouseListTabState();
}

class _WarehouseListTabState extends State<WarehouseListTab> {
  Future<void> _edit([Warehouse? row]) async {
    final saved = await showModalBottomSheet<bool>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _WarehouseForm(row: row));
    if (saved == true) widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    return ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 24), children: [
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: () => _edit(), icon: const Icon(Icons.add, size: 18), label: Text(context.tr('warehouse.new')))),
      const SizedBox(height: 8),
      for (final w in widget.warehouses)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Opacity(
            opacity: w.isActive ? 1 : 0.55,
            child: ListTile(
              onTap: () => widget.onOpen(w.id),
              title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w900)),
              subtitle: Text(
                [
                  context.tr('warehouse.kind.${w.kind}'),
                  regionName(w.regionCode),
                  if (w.serviceCenterName != null) w.serviceCenterName!,
                  '${context.tr('warehouse.units')}: ${w.units}',
                  if (w.keepers.isNotEmpty) '${context.tr('warehouse.keepers')}: ${w.keepers.join(', ')}',
                  context.tr('warehouse.etaShort', params: {'same': w.leadDaysSameRegion, 'other': w.leadDaysOtherRegion}),
                  if (!w.isActive) context.tr('warehouse.off'),
                ].join(' · '),
              ),
              trailing: IconButton(tooltip: context.tr('common.edit'), onPressed: () => _edit(w), icon: const Icon(Icons.edit_outlined)),
            ),
          ),
        ),
    ]);
  }
}

class _WarehouseForm extends StatefulWidget {
  const _WarehouseForm({this.row});
  final Warehouse? row;
  @override
  State<_WarehouseForm> createState() => _WarehouseFormState();
}

class _WarehouseFormState extends State<_WarehouseForm> {
  late final _name = TextEditingController(text: widget.row?.name ?? '');
  late final _address = TextEditingController(text: widget.row?.address ?? '');
  late final _phone = TextEditingController(text: widget.row?.phone ?? '');
  late final _note = TextEditingController(text: widget.row?.note ?? '');
  late final _same = TextEditingController(text: '${widget.row?.leadDaysSameRegion ?? 1}');
  late final _other = TextEditingController(text: '${widget.row?.leadDaysOtherRegion ?? 3}');
  late String kind = (widget.row == null || widget.row!.isCentral) ? 'regional' : widget.row!.kind;
  late String region = widget.row?.regionCode ?? '01';
  late String? centerId = widget.row?.serviceCenterId;
  late bool active = widget.row?.isActive ?? true;
  List<Json> centers = [];

  bool get _central => widget.row?.isCentral ?? false;
  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _loadCenters();
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone, _note, _same, _other]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadCenters() async {
    try {
      final r = await _api.get('/api/staff/service-centers');
      if (mounted) setState(() => centers = asList(asMap(r)['centers']).map(asMap).toList());
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showSnack(context, tr('common.name'), error: true);
      return;
    }
    final body = {
      'name': _name.text.trim(),
      'kind': kind,
      'regionCode': region,
      'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'serviceCenterId': kind == 'branch' ? centerId : null,
      'leadDaysSameRegion': int.tryParse(_same.text.trim()) ?? 0,
      'leadDaysOtherRegion': int.tryParse(_other.text.trim()) ?? 0,
      'note': _note.text.trim().isEmpty ? null : _note.text.trim(),
      if (widget.row != null) 'isActive': active,
    };
    try {
      if (widget.row == null) {
        await _api.post('/api/staff/warehouses', body: body);
      } else {
        await _api.patch('/api/staff/warehouses/${widget.row!.id}', body: body);
      }
      if (!mounted) return;
      showSnack(context, tr('warehouse.saved'));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr(widget.row == null ? 'warehouse.new' : 'warehouse.edit'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Labeled(context.tr('common.name'), child: TextField(controller: _name, maxLength: 100)),
            if (!_central)
              Labeled(
                context.tr('warehouse.kindLabel'),
                child: SegmentedChoice<String>(value: kind, options: {'regional': context.tr('warehouse.kind.regional'), 'branch': context.tr('warehouse.kind.branch')}, onChanged: (v) => setState(() => kind = v)),
              ),
            Labeled(
              context.tr('common.region'),
              child: DropdownButtonFormField<String>(
                initialValue: regionCodes.contains(region) ? region : null,
                isExpanded: true,
                items: [for (final code in regionCodes) DropdownMenuItem(value: code, child: Text(regionName(code)))],
                onChanged: (v) => setState(() => region = v ?? region),
              ),
            ),
            if (kind == 'branch' && !_central)
              Labeled(
                context.tr('warehouse.serviceCenter'),
                hint: context.tr('warehouse.serviceCenterHint'),
                child: DropdownButtonFormField<String?>(
                  initialValue: centers.any((c) => c['id'] == centerId) ? centerId : null,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem<String?>(value: null, child: Text(context.tr('common.dash'))),
                    for (final c in centers) DropdownMenuItem<String?>(value: c['id'].toString(), child: Text(c['name'].toString(), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => centerId = v),
                ),
              ),
            Row(children: [
              Expanded(child: Labeled(context.tr('warehouse.daysSame'), hint: context.tr('warehouse.daysHint'), child: TextField(controller: _same, keyboardType: TextInputType.number))),
              const SizedBox(width: 12),
              Expanded(child: Labeled(context.tr('warehouse.daysOther'), child: TextField(controller: _other, keyboardType: TextInputType.number))),
            ]),
            Labeled(context.tr('common.address'), child: TextField(controller: _address, maxLength: 200)),
            Labeled(context.tr('common.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone, maxLength: 40)),
            Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 300)),
            if (widget.row != null && !_central) SwitchListTile(contentPadding: EdgeInsets.zero, value: active, onChanged: (v) => setState(() => active = v), title: Text(context.tr('warehouse.active'))),
            SizedBox(width: double.infinity, child: BusyButton(label: context.tr('common.save'), onPressed: _save)),
          ]),
        ),
      ),
    );
  }
}
