import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../common/estimate_widgets.dart';
import '../common/timeline_view.dart';
import 'actions.dart';

/// One job in detail: workflow, estimate, photos, services, parts, extras, outcome and completion.
class JobScreen extends StatefulWidget {
  const JobScreen({super.key, required this.jobId});
  final String jobId;
  @override
  State<JobScreen> createState() => _JobScreenState();
}

class _JobScreenState extends State<JobScreen> {
  late final TechRepository repo = context.read<TechRepository>();
  JobWork? work;
  Object? error;
  bool loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    repo.addListener(_onRepo);
    _load();
  }

  @override
  void dispose() {
    repo.removeListener(_onRepo);
    super.dispose();
  }

  void _onRepo() {
    final cached = repo.cachedWork(widget.jobId);
    if (mounted && cached != null && !_busy) setState(() => work = cached);
  }

  Future<void> _load() async {
    setState(() {
      loading = work == null;
      error = null;
    });
    try {
      final result = await repo.loadJob(widget.jobId);
      if (mounted) setState(() => work = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  TechActions get _actions => TechActions(context, repo);

  Future<void> _do(Future<JobWork?> Function() action) async {
    setState(() => _busy = true);
    try {
      final result = await action();
      if (mounted && result != null) setState(() => work = result);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _perform(String kind, Json args, {Uint8List? photo}) => _do(() => _actions.run(() => repo.perform(widget.jobId, kind, args, photo: photo)));

  @override
  Widget build(BuildContext context) {
    final data = work;
    return Scaffold(
      appBar: AppBar(
        title: Text(data == null ? context.tr('tech.openJob') : formatRequestId(data.job.displayId)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: data == null
          ? (loading ? const LoadingView() : ErrorView(error: error ?? ApiException(404, 'Not found', code: 'jobNotFound'), onRetry: _load))
          : _content(data),
      bottomNavigationBar: data == null || data.isDone ? null : _completeBar(data),
    );
  }

  Widget _content(JobWork data) {
    final repair = data.job.isRepair;
    final done = data.isDone;
    final left = <Widget>[
      _header(data),
      _timeline(data),
      if (repair && !done) _workflow(data),
      if (repair) _defect(data, done),
      if (repair) _estimate(data, done),
      if (data.notes.isNotEmpty) _notes(data),
    ];
    final right = <Widget>[
      _photos(data, done),
      _services(data, done),
      _parts(data, done),
      if (data.partOrders.isNotEmpty) _partOrders(data),
      _extras(data, done),
      if (repair) _ResolutionSection(key: ValueKey('${data.resolutionType}-${data.replacement?['serialNumber']}'), data: data, disabled: done || _busy, onSave: (args) => _perform('resolution', args)),
      _cost(data),
    ];
    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: w)]);
    return LayoutBuilder(builder: (context, constraints) {
      final twoColumns = constraints.maxWidth >= 900;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (repo.hasPending(widget.jobId))
              Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Brand.orangeTint, borderRadius: BorderRadius.circular(12)), child: Row(children: [const Icon(Icons.cloud_upload_outlined, color: Brand.orangeText, size: 18), const SizedBox(width: 8), Expanded(child: Text(context.tr('mobile.jobPending'), style: const TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w800, fontSize: 13)))])),
            if (twoColumns)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: column(left)), const SizedBox(width: 12), Expanded(child: column(right))])
            else
              column([...left, ...right]),
          ],
        ),
      );
    });
  }

  // ---- sections ----------------------------------------------------------------------------------------------

  Widget _header(JobWork data) {
    final job = data.job;
    final locale = Translator.I.locale;
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(formatRequestId(job.displayId), style: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w800, fontSize: 12)),
        Text(job.customer.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        Text('${job.product.name(locale)}${job.serialNumber != null ? ' · ${context.tr('serial.label')}: ${job.serialNumber}' : ''}', style: const TextStyle(color: Color(0xFF6B7280))),
        PhoneLink(job.customer.phone),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [TypeChip(job.type), LocationChip(job.locationType), WarrantyChip(job.warrantyStatus), StatusChip(job.status), if (job.isRepeat) Pill(context.tr('detail.repeat'), color: Brand.red, background: Brand.redTint)]),
        const SizedBox(height: 10),
        Text(job.issueDescription),
        if (job.isOnSite && job.customerLocation != null) ...[
          const SizedBox(height: 10),
          Text(job.customerLocation!.address, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563))),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: () => openUri(context, job.customerLocation!.mapsUri), icon: const Icon(Icons.navigation_outlined), label: Text(context.tr('maps.directions'))),
        ],
        if (job.scheduledAt != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('tech.scheduledFor', params: {'time': formatStamp(job.scheduledAt)}), style: const TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w800))),
        if (job.timer != null) Padding(padding: const EdgeInsets.only(top: 10), child: CountdownChip(job.timer!)),
      ]),
    );
  }

  Widget _timeline(JobWork data) => Section(title: context.tr('job.timeline'), hint: context.tr('job.timelineHint'), child: TimelineView(data.timeline));

  Widget _workflow(JobWork data) {
    final job = data.job;
    final buttons = <Widget>[];
    if (job.status == 'new') buttons.add(FilledButton(onPressed: _busy ? null : () => _do(() => _actions.status(job, 'diagnosing')), child: Text(context.tr('tech.startDiagnosis'))));
    if (job.status == 'diagnosing' || job.status == 'awaiting_parts') {
      buttons.add(FilledButton(onPressed: _busy ? null : () => _do(() => _actions.status(job, 'in_progress')), child: Text(job.status == 'awaiting_parts' ? context.tr('tech.partsArrived') : context.tr('tech.startRepair'))));
    }
    if (job.status == 'diagnosing' || job.status == 'in_progress') {
      buttons.add(OutlinedButton(onPressed: _busy ? null : () => _do(() => _actions.status(job, 'awaiting_parts')), child: Text(context.tr('tech.needParts'))));
    }
    if (job.status == 'paused') buttons.add(FilledButton(onPressed: _busy ? null : () => _do(() => _actions.status(job, 'in_progress')), child: Text(context.tr('tech.resume'))));
    if (job.status != 'paused' && job.status != 'awaiting_decision') buttons.add(OutlinedButton(onPressed: _busy ? null : () => _do(() => _actions.pause(job)), child: Text(context.tr('tech.pause'))));
    return Section(
      title: context.tr('tech.workflow'),
      hint: context.tr('tech.workflowHint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, children: [StatusChip(job.status), if (data.decision != null) Pill(context.tr('decision.${data.decision}'))]),
        if (job.status == 'awaiting_decision') Container(margin: const EdgeInsets.only(top: 10), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Brand.amberTint, borderRadius: BorderRadius.circular(12)), child: Text(context.tr('tech.waitingDecision'), style: const TextStyle(color: Brand.amberText, fontWeight: FontWeight.w800))),
        for (final b in buttons) Padding(padding: const EdgeInsets.only(top: 10), child: b),
      ]),
    );
  }

  Widget _defect(JobWork data, bool done) {
    final locale = Translator.I.locale;
    return Section(
      title: context.tr('detail.defectCode'),
      hint: context.tr('tech.diagnosisHint'),
      child: DropdownButtonFormField<String?>(
        initialValue: data.job.defectCodeId,
        isExpanded: true,
        items: [
          DropdownMenuItem<String?>(value: null, child: Text(context.tr('common.dash'))),
          for (final code in data.defectCodes) DropdownMenuItem<String?>(value: code.id, child: Text('${code.code} · ${code.names.localized(locale)}', overflow: TextOverflow.ellipsis)),
        ],
        onChanged: done || _busy ? null : (value) => _perform('diagnosis', {'defectCodeId': value}),
      ),
    );
  }

  Widget _estimate(JobWork data, bool done) {
    final latest = data.estimates.isEmpty ? null : data.estimates.first;
    final job = data.job;
    final canBuild = !done && !(latest != null && (latest.status == 'sent' || latest.status == 'draft')) && const ['new', 'diagnosing', 'awaiting_decision', 'in_progress'].contains(job.status);
    final builder = EstimateBuilder(
      services: [for (final s in data.catalogServices) s],
      parts: [for (final p in data.catalogParts) p],
      allowDraft: false,
      onSubmit: (lines, note, send) async {
        await _perform('estimate', {'lines': lines, 'note': note, 'send': send});
        if (mounted) showSnack(context, context.tr(send ? 'estimate.sent' : 'estimate.saved'));
      },
    );
    return Section(
      title: context.tr('estimate.title'),
      hint: context.tr('estimate.techHint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final e in data.estimates) Padding(padding: const EdgeInsets.only(bottom: 12), child: EstimateCard(estimate: e)),
        if (canBuild)
          ExpansionTile(
            initiallyExpanded: latest == null || latest.status == 'declined' || latest.status == 'expired',
            tilePadding: EdgeInsets.zero,
            title: Text(context.tr('estimate.newEstimate'), style: const TextStyle(fontWeight: FontWeight.w800)),
            children: [builder],
          ),
      ]),
    );
  }

  Widget _notes(JobWork data) => Section(
        title: context.tr('notes.title'),
        hint: context.tr('notes.techHint'),
        child: Column(children: [
          for (final n in data.notes)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: n.authorScope == 'customer' ? Brand.orangeTint : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(n.text),
                const SizedBox(height: 4),
                Text('${n.authorScope == 'customer' ? context.tr('notes.customer') : (n.authorName ?? context.tr('notes.staff'))} · ${formatStamp(n.createdAt)}', style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              ]),
            ),
        ]),
      );

  Widget _photos(JobWork data, bool done) {
    final photos = data.photos;
    return Section(
      title: context.tr('job.photos'),
      hint: context.tr('job.photosHint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (photos.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.tr('job.noPhotos'), style: const TextStyle(color: Color(0xFF6B7280)))),
        if (photos.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: GridView.count(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final photo in photos)
                  Stack(fit: StackFit.expand, children: [
                    ClipRRect(borderRadius: BorderRadius.circular(12), child: JobImage(asString(photo['photoUrl']), height: 120)),
                    if (asString(photo['id']).startsWith('local-')) const Positioned(left: 6, bottom: 6, child: Icon(Icons.cloud_upload_outlined, color: Colors.white, size: 18)),
                    if (!done)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: InkWell(
                          onTap: _busy ? null : () => _perform('photoRemove', {'photoId': photo['id']}),
                          child: Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 16, color: Colors.white)),
                        ),
                      ),
                  ]),
              ],
            ),
          ),
        if (!done)
          PhotoPickerBar(onPicked: (list) async {
            for (final bytes in list) {
              await _perform('photo', {}, photo: bytes);
            }
          }),
      ]),
    );
  }

  Widget _services(JobWork data, bool done) {
    final locale = Translator.I.locale;
    return Section(
      title: context.tr('catalog.services'),
      hint: context.tr('job.servicesHint', params: {'category': context.tr('categories.${data.job.product.category}', def: data.job.product.category)}),
      child: data.catalogServices.isEmpty
          ? Text(context.tr('job.noServices'), style: const TextStyle(color: Color(0xFF6B7280)))
          : Column(children: [
              for (final item in data.catalogServices)
                Builder(builder: (context) {
                  final line = data.serviceLines.cast<Json?>().firstWhere((l) => l!['serviceCatalogItemId'] == item.id, orElse: () => null);
                  final selected = line != null;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: selected ? Brand.purpleTint : const Color(0xFFF9FAFB),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? Brand.purple : Brand.border)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: done || _busy ? null : () => selected ? _perform('serviceRemove', {'lineId': line['id']}) : _perform('serviceAdd', {'serviceCatalogItemId': item.id}),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          child: Row(children: [
                            Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? Brand.purple : const Color(0xFF9CA3AF)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.names.localized(locale), style: const TextStyle(fontWeight: FontWeight.w700))),
                            Text(formatMoney(item.price), style: const TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF4B5563))),
                          ]),
                        ),
                      ),
                    ),
                  );
                }),
            ]),
    );
  }

  Widget _parts(JobWork data, bool done) {
    final locale = Translator.I.locale;
    return Section(
      title: context.tr('catalog.parts'),
      hint: context.tr('job.partsHint'),
      child: data.catalogParts.isEmpty
          ? Text(context.tr('job.noParts'), style: const TextStyle(color: Color(0xFF6B7280)))
          : Column(children: [
              for (final item in data.catalogParts)
                Builder(builder: (context) {
                  final line = data.partLines.cast<Json?>().firstWhere((l) => l!['sparePartId'] == item.id, orElse: () => null);
                  final stock = item.stockQuantity ?? 0;
                  final out = stock <= 0;
                  final blocked = out && data.blockZeroStock && line == null;
                  final qty = line == null ? 0 : asInt(line['quantity']);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: line != null ? Brand.orangeTint : const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: line != null ? Brand.orange : Brand.border)),
                    child: Row(children: [
                      Expanded(
                        child: InkWell(
                          onTap: done || _busy || blocked || line != null ? null : () => _perform('partAdd', {'sparePartId': item.id, 'quantity': 1}),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(item.names.localized(locale), style: const TextStyle(fontWeight: FontWeight.w700)),
                              Text(context.tr('job.stockLine', params: {'price': formatMoney(item.price), 'count': stock}), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                              if (out) Text(data.blockZeroStock ? context.tr('job.zeroStockBlock') : context.tr('job.zeroStockWarn'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.amberText)) else if (item.lowStock) Text(context.tr('catalog.lowStock'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.amberText)),
                            ]),
                          ),
                        ),
                      ),
                      if (out && line == null)
                        OutlinedButton(
                          onPressed: done || _busy ? null : () => _perform('partOrder', {'sparePartId': item.id, 'quantity': 1}),
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: 12)),
                          child: Text(context.tr('parts.order')),
                        ),
                      if (line != null) ...[
                        IconButton(onPressed: done || _busy ? null : () => _perform('partQty', {'lineId': line['id'], 'quantity': qty - 1}), icon: const Icon(Icons.remove_circle_outline)),
                        Text('$qty', style: const TextStyle(fontWeight: FontWeight.w900)),
                        IconButton(onPressed: done || _busy || (out && data.blockZeroStock) ? null : () => _perform('partQty', {'lineId': line['id'], 'quantity': qty + 1}), icon: const Icon(Icons.add_circle_outline)),
                      ],
                    ]),
                  );
                }),
            ]),
    );
  }

  Widget _partOrders(JobWork data) {
    final locale = Translator.I.locale;
    return Section(
      title: context.tr('parts.orders'),
      hint: context.tr('parts.ordersHint'),
      child: Column(children: [
        for (final order in data.partOrders)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${Named.fromJson(order).localized(locale)} × ${order['quantity']}', style: const TextStyle(fontWeight: FontWeight.w700)),
            trailing: Pill(context.tr('parts.status.${order['status']}')),
          ),
      ]),
    );
  }

  Widget _extras(JobWork data, bool done) {
    return Section(
      title: context.tr('detail.extras'),
      hint: context.tr('job.extraHint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final item in data.extraExpenses)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(asString(item['description']), style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(formatMoney(asDouble(item['price']))),
            trailing: done ? null : IconButton(onPressed: _busy ? null : () => _perform('extraRemove', {'expenseId': item['id']}), icon: const Icon(Icons.delete_outline)),
          ),
        if (!done) _ExtraForm(onAdd: (description, price) => _perform('extraAdd', {'description': description, 'price': price})),
      ]),
    );
  }

  Widget _cost(JobWork data) {
    final covered = data.coveredByWarranty;
    return Section(
      title: context.tr('job.cost'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        InfoRow(context.tr('catalog.services'), formatMoney(data.costValue('servicesTotal'))),
        InfoRow(context.tr('catalog.parts'), formatMoney(data.costValue('partsTotal'))),
        InfoRow(context.tr('job.additional'), formatMoney(data.costValue('extrasTotal'))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: covered ? Brand.greenTint : Brand.orangeTint, borderRadius: BorderRadius.circular(12)),
          child: Text(
            covered ? context.tr('detail.warrantyPays', params: {'amount': formatMoney(data.costValue('chargedTotal'))}) : context.tr('detail.customerPays', params: {'amount': formatMoney(data.costValue('chargedTotal'))}),
            style: TextStyle(fontWeight: FontWeight.w900, color: covered ? Brand.green : Brand.orangeText),
          ),
        ),
      ]),
    );
  }

  Widget _completeBar(JobWork data) {
    final missing = data.missing;
    final list = missing.map((code) => tr('job.gap.$code')).join(', ');
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Brand.border))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (missing.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(context.tr('job.stillNeed', params: {'list': list}), textAlign: TextAlign.center, style: const TextStyle(color: Brand.orangeText, fontSize: 12, fontWeight: FontWeight.w800))),
          BusyButton(
            label: context.tr('job.completeAmount', params: {'amount': formatMoney(data.costValue('chargedTotal'))}),
            icon: Icons.check_circle_outline,
            enabled: missing.isEmpty && !_busy,
            onPressed: () async {
              final result = await _actions.complete(data.job);
              if (result != null && mounted) {
                setState(() => work = result);
                Navigator.of(context).pop();
              }
            },
          ),
        ]),
      ),
    );
  }
}

class _ExtraForm extends StatefulWidget {
  const _ExtraForm({required this.onAdd});
  final Future<void> Function(String description, double price) onAdd;
  @override
  State<_ExtraForm> createState() => _ExtraFormState();
}

class _ExtraFormState extends State<_ExtraForm> {
  bool _open = false;
  final _description = TextEditingController();
  final _price = TextEditingController();

  @override
  Widget build(BuildContext context) {
    if (!_open) return OutlinedButton.icon(onPressed: () => setState(() => _open = true), icon: const Icon(Icons.add), label: Text(context.tr('detail.extras')));
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Labeled(context.tr('job.description'), child: TextField(controller: _description)),
        Labeled(context.tr('catalog.priceSom'), child: TextField(controller: _price, keyboardType: TextInputType.number)),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => setState(() => _open = false), child: Text(context.tr('common.cancel')))),
          const SizedBox(width: 10),
          Expanded(
            child: BusyButton(
              label: context.tr('job.saveExpense'),
              onPressed: () async {
                final price = double.tryParse(_price.text.replaceAll(' ', ''));
                if (_description.text.trim().isEmpty || price == null || price < 0) return;
                await widget.onAdd(_description.text.trim(), price);
                if (mounted) {
                  _description.clear();
                  _price.clear();
                  setState(() => _open = false);
                }
              },
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ResolutionSection extends StatefulWidget {
  const _ResolutionSection({super.key, required this.data, required this.disabled, required this.onSave});
  final JobWork data;
  final bool disabled;
  final void Function(Json args) onSave;
  @override
  State<_ResolutionSection> createState() => _ResolutionSectionState();
}

class _ResolutionSectionState extends State<_ResolutionSection> {
  late String mode = widget.data.resolutionType == 'replace' ? 'replace' : 'repair';
  late String? productId = widget.data.replacement?['productId']?.toString() ?? (widget.data.replacementProducts.isNotEmpty ? widget.data.replacementProducts.first.id : widget.data.job.product.id);
  late final TextEditingController serial = TextEditingController(text: widget.data.replacement?['serialNumber']?.toString() ?? '');

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final locale = Translator.I.locale;
    return Section(
      title: context.tr('job.resolution'),
      hint: context.tr('job.resolutionHint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedChoice<String>(
          value: mode,
          options: {'repair': context.tr('resolution.repair'), 'replace': context.tr('resolution.replace')},
          onChanged: widget.disabled
              ? (_) {}
              : (next) {
                  setState(() => mode = next);
                  if (next == 'repair' && data.resolutionType == 'replace') widget.onSave({'resolutionType': 'repair'});
                },
        ),
        if (mode == 'replace') ...[
          const SizedBox(height: 12),
          Labeled(
            context.tr('job.replacementProduct'),
            child: DropdownButtonFormField<String>(
              initialValue: data.replacementProducts.any((p) => p.id == productId) ? productId : null,
              isExpanded: true,
              items: [for (final p in data.replacementProducts) DropdownMenuItem(value: p.id, child: Text('${p.name(locale)} · ${p.sku}', overflow: TextOverflow.ellipsis))],
              onChanged: widget.disabled ? null : (v) => setState(() => productId = v),
            ),
          ),
          Labeled(context.tr('job.serialNumber'), child: TextField(controller: serial, enabled: !widget.disabled, onChanged: (_) => setState(() {}))),
          if (data.replacement != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('job.replacementSaved', params: {'product': Named.fromJson(data.replacement).localized(locale), 'serial': data.replacement!['serialNumber']}), style: const TextStyle(color: Brand.green, fontWeight: FontWeight.w800))),
          FilledButton(onPressed: widget.disabled || serial.text.trim().isEmpty || productId == null ? null : () => widget.onSave({'resolutionType': 'replace', 'productId': productId, 'serialNumber': serial.text.trim()}), child: Text(context.tr('job.saveReplacement'))),
        ],
      ]),
    );
  }
}
