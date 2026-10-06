import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

const _intakeItems = ['powers_on', 'screen_ok', 'body_scratches', 'accessories_included', 'original_packaging', 'water_damage_signs'];

class _CustomerRow {
  _CustomerRow(Json m)
      : id = asString(m['id']),
        name = asString(m['name']),
        phone = asString(m['phone']),
        address = m['address']?.toString();
  final String id;
  final String name;
  final String phone;
  final String? address;
}

/// Creates a repair or installation request for a customer (front desk or dispatcher).
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});
  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  String type = 'repair';
  _CustomerRow? customer;
  List<Json> sales = [];
  List<Json> products = [];
  List<TechnicianInfo> technicians = [];
  List<ServiceCenter> centers = [];
  String? saleId;
  String? productId;
  String defectType = 'failed_during_use';
  String locationType = 'in_shop';
  String priority = 'medium';
  String techType = 'service_center';
  String assign = 'auto';
  String? technicianId;
  String? centerId;
  DateTime? scheduledAt;
  final Set<String> checklist = {};
  final _serial = TextEditingController();
  final _issue = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _signature = GlobalKey<SignaturePadState>();
  bool _ready = false;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final results = await Future.wait([_api.get('/api/staff/products'), _api.get('/api/staff/technicians'), _api.get('/api/staff/service-centers').catchError((_) => <String, dynamic>{'centers': []})]);
      if (!mounted) return;
      setState(() {
        products = asList(asMap(results[0])['products']);
        technicians = asList(asMap(results[1])['technicians']).map(TechnicianInfo.new).toList();
        centers = asList(asMap(results[2])['centers']).map(ServiceCenter.new).toList();
        _ready = true;
      });
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  Future<void> _pickCustomer() async {
    final picked = await showModalBottomSheet<_CustomerRow>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _CustomerPicker(api: _api));
    if (picked == null) return;
    setState(() {
      customer = picked;
      saleId = null;
      sales = [];
      if (_address.text.isEmpty && picked.address != null) _address.text = picked.address!;
    });
    try {
      final result = await _api.get('/api/staff/sales', query: {'customerId': picked.id});
      if (mounted) setState(() => sales = asList(asMap(result)['sales']));
    } catch (_) {}
  }

  bool get _onSite => locationType == 'on_site' || type == 'installation';

  Future<void> _submit({bool allowDuplicate = false}) async {
    if (customer == null) return showSnack(context, context.tr('newRequest.selectCustomer'), error: true);
    final sale = sales.cast<Json?>().firstWhere((s) => s!['id'] == saleId, orElse: () => null);
    final product = sale != null ? asMap(sale['product'])['id']?.toString() : productId;
    if (product == null) return showSnack(context, context.tr('newRequest.selectProduct'), error: true);
    if (_issue.text.trim().isEmpty) return showSnack(context, context.tr('newRequest.issueHint'), error: true);
    if (_onSite && _address.text.trim().isEmpty) return showSnack(context, context.tr('newRequest.addressPlaceholder'), error: true);
    final signature = type == 'repair' && !_onSite ? await _signature.currentState?.toDataUrl() : null;
    final body = <String, dynamic>{
      'type': type,
      'customerId': customer!.id,
      if (saleId != null) 'saleId': saleId,
      'productId': product,
      if (_serial.text.trim().isNotEmpty) 'serialNumber': _serial.text.trim(),
      'issueDescription': _issue.text.trim(),
      if (type == 'repair') 'defectType': defectType,
      'locationType': _onSite ? 'on_site' : 'in_shop',
      if (_onSite) 'customerLocation': {'address': _address.text.trim()},
      'technicianTypeRequired': _onSite ? 'mobile' : techType,
      'priority': priority,
      'source': 'rizo_service',
      if (assign == 'auto') 'autoAssign': true,
      if (assign == 'manual' && technicianId != null) 'assignedTechnicianId': technicianId,
      if (centerId != null) 'serviceCenterId': centerId,
      if (scheduledAt != null) 'scheduledAt': scheduledAt!.toUtc().toIso8601String(),
      if (allowDuplicate) 'allowDuplicate': true,
      if (checklist.isNotEmpty || _notes.text.trim().isNotEmpty || signature != null) 'intake': {'checklist': checklist.toList(), if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(), 'signatureDataUrl': ?signature},
    };
    try {
      await _api.post('/api/staff/requests', body: body);
      if (!mounted) return;
      showSnack(context, context.tr('newRequest.created'));
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'duplicateRequest') {
        final id = asString(e.details?['displayId']);
        final again = await confirmDialog(context, context.tr('newRequest.duplicateTitle'), body: context.tr('newRequest.duplicateBody', params: {'id': formatRequestId(id)}), confirmLabel: context.tr('newRequest.createAnyway'));
        if (again && mounted) await _submit(allowDuplicate: true);
      } else {
        showSnack(context, Translator.I.errorMessage(e), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final candidates = technicians.where((t) => t.technicianType == (_onSite ? 'mobile' : techType)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('newRequest.title'))),
      body: !_ready
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.all(14), children: [
              SegmentedChoice<String>(value: type, options: {'repair': context.tr('type.repair'), 'installation': context.tr('type.installation')}, onChanged: (v) => setState(() {
                    type = v;
                    if (v == 'installation') locationType = 'on_site';
                  })),
              const SizedBox(height: 16),
              Labeled(
                context.tr('newRequest.customer'),
                child: OutlinedButton.icon(onPressed: _pickCustomer, icon: const Icon(Icons.person_outline), label: Align(alignment: Alignment.centerLeft, child: Text(customer == null ? context.tr('newRequest.selectCustomer') : '${customer!.name} · ${formatPhone(customer!.phone)}', overflow: TextOverflow.ellipsis))),
              ),
              if (customer != null && sales.isNotEmpty)
                Labeled(
                  context.tr('newRequest.sale'),
                  hint: context.tr('newRequest.saleHint'),
                  child: DropdownButtonFormField<String?>(
                    initialValue: saleId,
                    isExpanded: true,
                    items: [DropdownMenuItem<String?>(value: null, child: Text(context.tr('newRequest.noSale'))), for (final s in sales) DropdownMenuItem<String?>(value: asString(s['id']), child: Text('${s['invoiceNumber']} · ${Named.fromJson(s['product']).localized(locale)}', overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() {
                      saleId = v;
                      final sale = sales.cast<Json?>().firstWhere((s) => s!['id'] == v, orElse: () => null);
                      if (sale?['serialNumber'] != null && _serial.text.isEmpty) _serial.text = sale!['serialNumber'].toString();
                    }),
                  ),
                ),
              if (saleId == null)
                Labeled(
                  context.tr('newRequest.product'),
                  child: DropdownButtonFormField<String?>(
                    initialValue: productId,
                    isExpanded: true,
                    hint: Text(context.tr('newRequest.selectProduct')),
                    items: [for (final p in products) DropdownMenuItem<String?>(value: asString(p['id']), child: Text('${Named.fromJson(p).localized(locale)} · ${p['sku']}', overflow: TextOverflow.ellipsis))],
                    onChanged: (v) => setState(() => productId = v),
                  ),
                ),
              Labeled(context.tr('serial.label'), hint: context.tr('serial.hint'), child: TextField(controller: _serial)),
              Labeled(context.tr('newRequest.issue'), hint: context.tr('newRequest.issueHint'), child: TextField(controller: _issue, maxLines: 4, minLines: 3)),
              if (type == 'repair') Labeled(context.tr('newRequest.defect'), child: SegmentedChoice<String>(value: defectType, options: {'dead_on_arrival': context.tr('defect.dead_on_arrival'), 'failed_during_use': context.tr('defect.failed_during_use')}, onChanged: (v) => setState(() => defectType = v))),
              if (type == 'repair') Labeled(context.tr('newRequest.location'), child: SegmentedChoice<String>(value: locationType, options: {'in_shop': context.tr('location.in_shop'), 'on_site': context.tr('location.on_site')}, onChanged: (v) => setState(() => locationType = v))),
              if (type == 'installation') Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(context.tr('newRequest.installationOnlyOnSite'), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w700, fontSize: 13))),
              if (_onSite)
                Labeled(
                  context.tr('newRequest.address'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    TextField(controller: _address, maxLines: 2, minLines: 1, decoration: InputDecoration(hintText: context.tr('newRequest.addressPlaceholder'))),
                    if (customer?.address != null) TextButton(onPressed: () => setState(() => _address.text = customer!.address!), child: Align(alignment: Alignment.centerLeft, child: Text(context.tr('newRequest.useProfileAddress')))),
                  ]),
                ),
              Labeled(context.tr('newRequest.priority'), child: SegmentedChoice<String>(value: priority, options: {for (final p in ['low', 'medium', 'high', 'urgent']) p: context.tr('priority.$p')}, onChanged: (v) => setState(() => priority = v))),
              if (!_onSite) Labeled(context.tr('newRequest.technicianType'), child: SegmentedChoice<String>(value: techType, options: {'service_center': context.tr('techType.service_center'), 'mobile': context.tr('techType.mobile')}, onChanged: (v) => setState(() => techType = v))),
              Labeled(
                context.tr('detail.assignment'),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SegmentedChoice<String>(value: assign, options: {'auto': context.tr('mobile.assignAuto'), 'manual': context.tr('mobile.assignManual'), 'unassigned': context.tr('mobile.assignNone')}, onChanged: (v) => setState(() => assign = v)),
                  if (assign == 'manual')
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: DropdownButtonFormField<String?>(
                        initialValue: candidates.any((t) => t.id == technicianId) ? technicianId : null,
                        isExpanded: true,
                        hint: Text(context.tr('newRequest.selectTechnician')),
                        items: [for (final t in candidates) DropdownMenuItem<String?>(value: t.id, child: Text('${t.name} · ${t.isAvailable ? context.tr('common.free') : context.tr('shell.busy')} · ${context.tr('kanban.openJobs', params: {'count': t.openJobCount})}', overflow: TextOverflow.ellipsis))],
                        onChanged: (v) => setState(() => technicianId = v),
                      ),
                    ),
                ]),
              ),
              if (centers.isNotEmpty)
                Labeled(context.tr('centers.center'), child: DropdownButtonFormField<String?>(initialValue: centerId, isExpanded: true, items: [DropdownMenuItem<String?>(value: null, child: Text(context.tr('centers.auto'))), for (final c in centers) DropdownMenuItem<String?>(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => centerId = v))),
              Labeled(
                _onSite ? context.tr('newRequest.visitTime') : context.tr('newRequest.appointment'),
                hint: context.tr('newRequest.visitTimeHint'),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await pickDateTime(context, initial: scheduledAt);
                    if (picked != null) setState(() => scheduledAt = picked);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(scheduledAt == null ? context.tr('common.dash') : formatStamp(scheduledAt)),
                ),
              ),
              if (type == 'repair') ...[
                const SizedBox(height: 4),
                Text(context.tr('intake.title'), style: const TextStyle(fontWeight: FontWeight.w900)),
                Text(context.tr('intake.hint'), style: TextStyle(fontSize: 12, color: Brand.muted)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [for (final item in _intakeItems) FilterChip(label: Text(context.tr('intake.items.$item')), selected: checklist.contains(item), onSelected: (v) => setState(() => v ? checklist.add(item) : checklist.remove(item)))]),
                const SizedBox(height: 10),
                Labeled(context.tr('intake.notes'), child: TextField(controller: _notes, maxLines: 2, maxLength: 1000, decoration: InputDecoration(hintText: context.tr('intake.notesPlaceholder')))),
                if (!_onSite) Labeled(context.tr('intake.signature'), child: SignaturePad(key: _signature)),
              ],
              const SizedBox(height: 8),
              BusyButton(label: context.tr('newRequest.submit'), icon: Icons.check, onPressed: _submit),
              const SizedBox(height: 30),
            ]),
    );
  }
}

class _CustomerPicker extends StatefulWidget {
  const _CustomerPicker({required this.api});
  final ApiClient api;
  @override
  State<_CustomerPicker> createState() => _CustomerPickerState();
}

class _CustomerPickerState extends State<_CustomerPicker> {
  List<_CustomerRow> all = [];
  bool loading = true;
  bool creating = false;
  final _query = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.api.get('/api/staff/customers').then((r) {
      if (mounted) {
        setState(() {
            all = asList(asMap(r)['customers']).map(_CustomerRow.new).toList();
            loading = false;
          });
      }
    }).catchError((Object e) {
      if (mounted) {
        setState(() => loading = false);
        showSnack(context, context.errorText(e), error: true);
      }
    });
  }

  Future<void> _create() async {
    try {
      final r = await widget.api.post('/api/staff/customers', body: {'name': _name.text.trim(), 'phone': _phone.text.trim(), if (_address.text.trim().isNotEmpty) 'address': _address.text.trim()});
      if (mounted) Navigator.pop(context, _CustomerRow(asMap(asMap(r)['customer'])));
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final shown = all.where((c) => q.isEmpty || c.name.toLowerCase().contains(q) || (digits.length >= 3 && c.phone.contains(digits))).take(60).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.8,
        child: creating
            ? ListView(padding: const EdgeInsets.all(16), children: [
                Labeled(context.tr('common.name'), child: TextField(controller: _name)),
                Labeled(context.tr('common.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone)),
                Labeled(context.tr('common.address'), child: TextField(controller: _address)),
                BusyButton(label: context.tr('common.save'), onPressed: _create),
                TextButton(onPressed: () => setState(() => creating = false), child: Text(context.tr('common.cancel'))),
              ])
            : Column(children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(children: [
                    Expanded(child: TextField(controller: _query, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('search.placeholder')))),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(onPressed: () => setState(() => creating = true), icon: const Icon(Icons.person_add_alt), tooltip: context.tr('mobile.newCustomer')),
                  ]),
                ),
                Expanded(
                  child: loading
                      ? const LoadingView()
                      : ListView(children: [for (final c in shown) ListTile(title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(formatPhone(c.phone)), onTap: () => Navigator.pop(context, c))]),
                ),
              ]),
      ),
    );
  }
}
