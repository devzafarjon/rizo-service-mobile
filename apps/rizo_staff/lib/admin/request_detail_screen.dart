import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rizo_core/rizo_core.dart';

import '../common/estimate_widgets.dart';
import '../common/timeline_view.dart';

const _decidable = ['new', 'diagnosing', 'awaiting_decision', 'awaiting_parts', 'in_progress'];
const _methods = ['cash', 'card', 'transfer', 'payme', 'click', 'other'];
const _priorities = ['low', 'medium', 'high', 'urgent'];

/// A request in full for the office: status, assignment, decision, estimate, payments, notes and pickup.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  Json? data;
  List<TechnicianInfo> technicians = [];
  Object? error;
  bool loading = true;
  bool allowUnpaid = false;

  StaffSession get _session => context.read<StaffSession>();
  ApiClient get _api => _session.api;
  String get _path => '/api/staff/requests/${widget.requestId}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final result = await _api.get(_path);
      final techs = technicians.isEmpty ? await _api.get('/api/staff/technicians') : null;
      if (!mounted) return;
      setState(() {
        data = asMap(result);
        if (techs != null) technicians = asList(asMap(techs)['technicians']).map(TechnicianInfo.new).toList();
      });
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  /// Runs a change, shows the result and reloads.
  Future<bool> _call(Future<Object?> Function() action, {String? success}) async {
    try {
      await action();
      if (mounted && success != null) showSnack(context, success);
      await _load();
      return true;
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
      return false;
    }
  }

  Future<void> _patch(Json body, {String? success}) => _call(() => _api.patch(_path, body: body), success: success ?? tr('slideOver.saved'));

  Future<void> _move(Job job, String status) async {
    if (status == 'paused') {
      final result = await showDialog<({String reason, double hours})>(context: context, builder: (_) => _PauseDialog(name: job.customer.name));
      if (result != null) await _patch({'status': 'paused', 'pauseReason': result.reason, 'pauseHours': result.hours});
    } else if (status == 'cancelled') {
      final reason = await promptDialog(context, title: tr('mobile.cancelTitle'), label: tr('decision.note'), required: false);
      if (reason != null) await _patch({'status': 'cancelled', if (reason.isNotEmpty) 'reason': reason});
    } else {
      await _patch({'status': status, if (status == 'picked_up') 'allowUnpaid': allowUnpaid});
    }
  }

  @override
  Widget build(BuildContext context) {
    final payload = data;
    return Scaffold(
      appBar: AppBar(title: Text(payload == null ? context.tr('detail.job') : formatRequestId(asString(asMap(payload['request'])['displayId']))), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: payload == null ? (loading ? const LoadingView() : ErrorView(error: error ?? ApiException(404, 'x', code: 'requestNotFound'), onRetry: _load)) : _body(payload),
    );
  }

  Widget _body(Json payload) {
    final job = Job(asMap(payload['request']));
    final role = _session.user?.role ?? 'admin';
    final locale = Translator.I.locale;
    final estimates = asList(payload['estimates']).map(Estimate.new).toList();
    final latest = estimates.isEmpty ? null : estimates.first;
    final openEstimate = latest != null && (latest.status == 'sent' || latest.status == 'draft') ? latest : null;
    final showDecision = job.isRepair && _decidable.contains(job.status);
    final next = nextStatuses(role, job).where((s) => !const ['replaced', 'refunded', 'rejected'].contains(s)).toList();
    final summary = MoneySummary.fromJson(payload['paymentSummary']);
    final payments = asList(payload['payments']).map(PaymentRow.new).toList();
    final notes = asList(payload['notes']).map(NoteRow.new).toList();
    final timeline = asList(payload['timeline']).map(TimelineEvent.new).toList();
    final candidates = technicians.where((t) => t.technicianType == job.technicianTypeRequired).toList();
    final canPickup = (job.status == 'ready' || job.status == 'completed') && job.locationType == 'in_shop' && job.pickupConfirmedAt == null;

    final left = <Widget>[
      _summary(job, locale),
      if (job.rejectionReason != null) _banner(context.tr('detail.rejectedBecause', params: {'reason': job.rejectionReason}), Brand.red, Brand.redTint),
      if (next.isNotEmpty) _moveCard(job, next, summary),
      _jobInfo(job, payload, locale),
      _assignment(job, candidates),
      if (showDecision) _decision(job, asList(payload['returnReasons']).map(DefectCode.new).toList()),
      if (job.isRepair) _estimateSection(job, estimates, openEstimate, payload),
      if (canPickup)
        PickupConfirmCard(onConfirm: (signature) async {
          await _call(() => _api.post('$_path/pickup', body: {'signature': signature, 'allowUnpaid': allowUnpaid}), success: tr('pickup.saved'));
        }),
    ];
    final right = <Widget>[
      _payments(job, summary, payments),
      _notes(notes),
      Section(title: context.tr('detail.timeline'), hint: context.tr('detail.timelineHint'), child: TimelineView(timeline)),
      _completion(payload, locale),
    ];
    Widget column(List<Widget> items) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final w in items) Padding(padding: const EdgeInsets.only(bottom: 12), child: w)]);

    return LayoutBuilder(builder: (context, c) {
      final two = c.maxWidth >= 900;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.all(12), children: [if (two) Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: column(left)), const SizedBox(width: 12), Expanded(child: column(right))]) else column([...left, ...right])]),
      );
    });
  }

  Widget _banner(String text, Color fg, Color bg) => Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800)));

  Widget _summary(Job job, String locale) {
    final trackUrl = job.trackingToken == null ? null : '${AppConfig.webUrl}/t/${job.trackingToken}';
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(job.customer.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        PhoneLink(job.customer.phone),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          TypeChip(job.type),
          StatusChip(job.status),
          Pill(context.tr('priority.${job.priority}')),
          WarrantyChip(job.warrantyStatus),
          LocationChip(job.locationType),
          if (job.isRepeat) Pill(context.tr('detail.repeat'), color: Brand.red, background: Brand.redTint),
          if (job.isLegallyOverdue) Pill(context.tr('detail.legalOverdue'), color: Brand.red, background: Brand.redTint),
          if (job.estimateStatus != null) Pill(context.tr('estimate.status.${job.estimateStatus}'), color: Brand.purple, background: Brand.purpleTint),
          if (job.payment.balance > 0) Pill(context.tr('detail.owes', params: {'amount': formatMoney(job.payment.balance)}), color: Brand.red, background: Brand.redTint),
        ]),
        if (job.timer != null) Padding(padding: const EdgeInsets.only(top: 10), child: CountdownChip(job.timer!)),
        if (job.activePause != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('tech.pausedReason', params: {'reason': job.activePause!.reason}), style: TextStyle(fontWeight: FontWeight.w700, color: Brand.subtle))),
        const SizedBox(height: 10),
        Text(job.issueDescription),
        if (trackUrl != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: trackUrl));
                if (mounted) showSnack(context, tr('detail.linkCopied'));
              },
              icon: const Icon(Icons.link),
              label: Text(context.tr('detail.copyTrackLink')),
            ),
          ),
      ]),
    );
  }

  Widget _moveCard(Job job, List<String> next, MoneySummary summary) {
    return Section(
      title: context.tr('slideOver.moveTo'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final status in next)
            ActionChip(
              label: Text(statusLabel(status)),
              backgroundColor: status == 'cancelled' ? Brand.redTint : Brand.surfaceAlt,
              labelStyle: TextStyle(fontWeight: FontWeight.w800, color: status == 'cancelled' ? Brand.red : Brand.ink),
              onPressed: () => _move(job, status),
            ),
        ]),
        if (summary.balance > 0 && next.contains('picked_up'))
          CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: allowUnpaid, onChanged: (v) => setState(() => allowUnpaid = v ?? false), title: Text(context.tr('detail.allowUnpaid'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700))),
      ]),
    );
  }

  Widget _jobInfo(Job job, Json payload, String locale) {
    final replacement = payload['replacement'] is Map ? asMap(payload['replacement']) : null;
    final codes = asList(payload['defectCodes']).map(DefectCode.new).toList();
    return Section(
      title: context.tr('detail.job'),
      child: Column(children: [
        InfoRow(context.tr('common.product'), '${job.product.name(locale)} · ${job.product.sku}'),
        InfoRow(context.tr('serial.label'), job.serialNumber),
        InfoRow(context.tr('detail.defect'), asString(job.raw['defectType']).isEmpty ? null : context.tr('defect.${job.raw['defectType']}')),
        if (job.isRepair)
          InfoRow(
            context.tr('detail.defectCode'),
            null,
            valueWidget: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                isExpanded: true,
                value: codes.any((c) => c.id == job.defectCodeId) ? job.defectCodeId : null,
                items: [DropdownMenuItem<String?>(value: null, child: Text(context.tr('common.dash'))), for (final c in codes) DropdownMenuItem<String?>(value: c.id, child: Text('${c.code} · ${c.names.localized(locale)}', overflow: TextOverflow.ellipsis))],
                onChanged: (v) => _patch({'defectCodeId': v}),
              ),
            ),
          ),
        if (job.decision != null) InfoRow(context.tr('decision.title'), context.tr('decision.${job.decision}')),
        if (job.resolutionType != null) InfoRow(context.tr('job.resolution'), '${context.tr('resolution.${job.resolutionType}')}${replacement != null ? ' · ${Named.fromJson(replacement).localized(locale)} · ${replacement['serialNumber']}' : ''}'),
        InfoRow(context.tr('detail.source'), context.tr('source.${job.raw['source']}')),
        InfoRow(context.tr('detail.payment'), '${context.tr('payment.${job.paymentStatus}')}${job.isPaidRepair ? ' · ${context.tr('common.paidRepair')}' : ''}'),
        InfoRow(context.tr('common.created'), formatDateTime(job.createdAt)),
        if (job.legalDueAt != null) InfoRow(context.tr('detail.legalDue'), formatDateTime(job.legalDueAt)),
        if (job.serviceCenterName != null) InfoRow(context.tr('centers.center'), job.serviceCenterName),
        if (job.scheduledAt != null) InfoRow(context.tr('detail.scheduled'), formatStamp(job.scheduledAt)),
        if (job.enRouteAt != null) InfoRow(context.tr('detail.enRoute'), formatStamp(job.enRouteAt)),
        if (job.customerLocation != null)
          InfoRow(context.tr('detail.address'), null, valueWidget: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(job.customerLocation!.address, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), TextButton.icon(style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)), onPressed: () => openUri(context, job.customerLocation!.mapsUri), icon: const Icon(Icons.navigation_outlined, size: 16), label: Text(context.tr('maps.directions')))])),
      ]),
    );
  }

  Widget _assignment(Job job, List<TechnicianInfo> candidates) {
    return Section(
      title: context.tr('detail.assignment'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Labeled(
          '${context.tr('common.technician')} (${context.tr('techType.${job.technicianTypeRequired}')})',
          child: DropdownButtonFormField<String?>(
            initialValue: candidates.any((t) => t.id == job.assignedTechnicianId) ? job.assignedTechnicianId : null,
            isExpanded: true,
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(context.tr('common.unassigned'))),
              for (final t in candidates) DropdownMenuItem<String?>(value: t.id, child: Text('${t.name} · ${t.isAvailable ? context.tr('common.free') : context.tr('shell.busy')} · ${context.tr('kanban.openJobs', params: {'count': t.openJobCount})}', overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => _patch({'assignedTechnicianId': v}),
          ),
        ),
        Labeled(
          context.tr('common.priority'),
          child: DropdownButtonFormField<String>(
            initialValue: job.priority,
            items: [for (final p in _priorities) DropdownMenuItem(value: p, child: Text(context.tr('priority.$p')))],
            onChanged: (v) => v == null ? null : _patch({'priority': v}),
          ),
        ),
        Labeled(
          context.tr('detail.scheduled'),
          child: OutlinedButton.icon(
            onPressed: () async {
              final picked = await pickDateTime(context, initial: job.scheduledAt?.toLocal());
              if (picked != null) await _patch({'scheduledAt': picked.toUtc().toIso8601String()});
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(job.scheduledAt == null ? context.tr('common.dash') : formatStamp(job.scheduledAt)),
          ),
        ),
      ]),
    );
  }

  Widget _decision(Job job, List<DefectCode> returnReasons) {
    return Section(
      title: context.tr('decision.title'),
      hint: context.tr('decision.hint'),
      child: _DecisionForm(job: job, returnReasons: returnReasons, onSubmit: (body) => _call(() => _api.post('$_path/decision', body: body), success: tr('decision.applied'))),
    );
  }

  Widget _estimateSection(Job job, List<Estimate> estimates, Estimate? open, Json payload) {
    final services = asList(payload['matchingServices']).map(CatalogChoice.new).toList();
    final parts = asList(payload['matchingParts']).map(CatalogChoice.new).toList();
    return Section(
      title: context.tr('estimate.title'),
      hint: context.tr('estimate.hint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final e in estimates)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: EstimateCard(estimate: e, actions: [
              if (e.status == 'draft') BusyButton(label: context.tr('estimate.sendToCustomer'), icon: Icons.send_outlined, onPressed: () => _call(() => _api.post('$_path/estimates/${e.id}/send', body: {}), success: tr('estimate.sent'))),
              if (e.status == 'sent' || e.status == 'draft') ...[
                const SizedBox(height: 8),
                BusyButton(label: context.tr('estimate.approveForCustomer'), outlined: true, onPressed: () => _call(() => _api.post('$_path/estimates/${e.id}/approve', body: {}))),
              ],
              if (e.status == 'sent') ...[
                const SizedBox(height: 8),
                BusyButton(
                  label: context.tr('estimate.declineForCustomer'),
                  outlined: true,
                  danger: true,
                  onPressed: () async {
                    final reason = await promptDialog(context, title: context.tr('estimate.declineForCustomer'), label: context.tr('estimate.declineReason'), required: false);
                    if (reason != null) await _call(() => _api.post('$_path/estimates/${e.id}/decline', body: {'reason': reason}));
                  },
                ),
              ],
            ]),
          ),
        if (open == null && _decidable.contains(job.status))
          ExpansionTile(
            initiallyExpanded: estimates.isEmpty,
            tilePadding: EdgeInsets.zero,
            title: Text(context.tr('estimate.newEstimate'), style: const TextStyle(fontWeight: FontWeight.w800)),
            children: [
              EstimateBuilder(
                services: services,
                parts: parts,
                onSubmit: (lines, note, send) async {
                  await _call(() => _api.post('$_path/estimates', body: {'lines': lines, 'note': note, 'send': send}), success: tr(send ? 'estimate.sent' : 'estimate.saved'));
                },
              ),
            ],
          ),
      ]),
    );
  }

  Widget _payments(Job job, MoneySummary summary, List<PaymentRow> payments) {
    return Section(
      title: context.tr('payments.title'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (final (label, value, color) in [
            (context.tr('payments.due'), summary.due, Brand.ink),
            (context.tr('payments.paid'), summary.paid, Brand.green),
            (context.tr('payments.balance'), summary.balance, summary.balance > 0 ? Brand.red : Brand.green),
          ])
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Brand.surfaceSoft, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Brand.muted)), Text(formatMoney(value), style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13))]),
              ),
            ),
        ]),
        const SizedBox(height: 10),
        if (payments.isEmpty) Text(context.tr('payments.none'), style: TextStyle(color: Brand.muted)),
        for (final p in payments)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text('${p.kind == 'refund' ? context.tr('payments.refund') : context.tr('payments.payment')} · ${context.tr('payments.methods.${p.method}')}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${formatStamp(p.createdAt)}${p.createdByName != null ? ' · ${p.createdByName}' : ''}'),
            trailing: Text('${p.kind == 'refund' ? '−' : '+'}${formatMoney(p.amount)}', style: TextStyle(fontWeight: FontWeight.w900, color: p.kind == 'refund' ? Brand.red : Brand.green)),
          ),
        const Divider(),
        _PaymentForm(balance: summary.balance, fiscal: job.raw['fiscalReceiptNumber']?.toString(), onSubmit: (body) => _call(() => _api.post('$_path/payments', body: body), success: tr('payments.saved'))),
      ]),
    );
  }

  Widget _notes(List<NoteRow> notes) {
    return Section(
      title: context.tr('notes.title'),
      hint: context.tr('notes.hint'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (notes.isEmpty) Text(context.tr('notes.none'), style: TextStyle(color: Brand.muted)),
        for (final n in notes)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: n.authorScope == 'customer' ? Brand.orangeTint : (n.isVisibleToCustomer ? Brand.purpleTint : Brand.surfaceAlt), borderRadius: BorderRadius.circular(12)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(n.text),
              const SizedBox(height: 4),
              Text('${n.authorScope == 'customer' ? context.tr('notes.customer') : (n.authorName ?? context.tr('notes.staff'))} · ${formatStamp(n.createdAt)} · ${n.authorScope == 'customer' ? context.tr('notes.fromCustomer') : (n.isVisibleToCustomer ? context.tr('notes.visible') : context.tr('notes.internal'))}', style: TextStyle(fontSize: 12, color: Brand.muted)),
            ]),
          ),
        _NoteForm(onSubmit: (text, visible) => _call(() => _api.post('$_path/notes', body: {'text': text, 'visibleToCustomer': visible}), success: tr('notes.saved'))),
      ]),
    );
  }

  Widget _completion(Json payload, String locale) {
    final services = asList(payload['serviceLines']);
    final parts = asList(payload['partLines']);
    final extras = asList(payload['extraExpenses']);
    final photos = asList(payload['photos']);
    if (services.length + parts.length + extras.length + photos.length == 0) return const SizedBox.shrink();
    return Section(
      title: context.tr('detail.completion'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (services.isNotEmpty) ...[Text(context.tr('detail.servicesUsed'), style: const TextStyle(fontWeight: FontWeight.w800)), for (final s in services) InfoRow(Named.fromJson(s).localized(locale), formatMoney(asDouble(s['priceAtTime'])))],
        if (parts.isNotEmpty) ...[const SizedBox(height: 8), Text(context.tr('detail.partsUsed'), style: const TextStyle(fontWeight: FontWeight.w800)), for (final s in parts) InfoRow('${Named.fromJson(s).localized(locale)} × ${s['quantity']}', formatMoney(asDouble(s['lineTotal'])))],
        if (extras.isNotEmpty) ...[const SizedBox(height: 8), Text(context.tr('detail.extras'), style: const TextStyle(fontWeight: FontWeight.w800)), for (final s in extras) InfoRow(asString(s['description']), formatMoney(asDouble(s['price'])))],
        if (photos.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(context.tr('detail.photos'), style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          SizedBox(height: 90, child: ListView(scrollDirection: Axis.horizontal, children: [for (final p in photos) Padding(padding: const EdgeInsets.only(right: 8), child: SizedBox(width: 90, child: ClipRRect(borderRadius: BorderRadius.circular(10), child: JobImage(asString(p['photoUrl']), height: 90))))])),
        ],
      ]),
    );
  }
}

class _PauseDialog extends StatefulWidget {
  const _PauseDialog({required this.name});
  final String name;
  @override
  State<_PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<_PauseDialog> {
  final _reason = TextEditingController();
  double _hours = 4;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('tech.pauseTitle')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        TextField(controller: _reason, autofocus: true, maxLines: 2, minLines: 1, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: context.tr('tech.pauseReason'))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [for (final h in [1.0, 2.0, 4.0, 8.0, 24.0, 48.0]) ChoiceChip(label: Text(context.tr('tech.hoursShort', params: {'count': h.round()})), selected: _hours == h, onSelected: (_) => setState(() => _hours = h))]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common.cancel'))),
        TextButton(onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, (reason: _reason.text.trim(), hours: _hours)), child: Text(context.tr('tech.pauseSubmit'))),
      ],
    );
  }
}

class _DecisionForm extends StatefulWidget {
  const _DecisionForm({required this.job, required this.returnReasons, required this.onSubmit});
  final Job job;
  final List<DefectCode> returnReasons;
  final Future<bool> Function(Json body) onSubmit;
  @override
  State<_DecisionForm> createState() => _DecisionFormState();
}

class _DecisionFormState extends State<_DecisionForm> {
  late String decision = widget.job.warrantyStatus == 'in_warranty' ? 'warranty_repair' : 'paid_repair';
  final _note = TextEditingController();
  final _reason = TextEditingController();
  final _serial = TextEditingController();
  final _amount = TextEditingController();
  String method = 'cash';
  String? returnReasonId;
  bool goodwill = false;

  bool get _expired => widget.job.warrantyStatus != 'in_warranty';
  bool get _valid => decision == 'reject' ? _reason.text.trim().isNotEmpty : (decision == 'warranty_repair' ? (!_expired || goodwill) : true);

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final option in const ['warranty_repair', 'paid_repair', 'replace', 'refund', 'reject'])
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: decision == option ? Brand.purpleTint : Brand.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: decision == option ? Brand.purple : Brand.border)),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => decision = option),
              child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('decision.$option'), style: const TextStyle(fontWeight: FontWeight.w800)), Text(context.tr('decision.${option}Hint'), style: TextStyle(fontSize: 12, color: Brand.muted))])),
            ),
          ),
        ),
      if (decision == 'warranty_repair' && _expired) CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: goodwill, onChanged: (v) => setState(() => goodwill = v ?? false), title: Text(context.tr('decision.goodwill'), style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text(context.tr('decision.goodwillHint'))),
      if (decision == 'paid_repair') Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('decision.paidNext'), style: TextStyle(color: Brand.subtle))),
      if (decision == 'replace') Labeled(context.tr('decision.newSerial'), hint: context.tr('decision.newSerialHint'), child: TextField(controller: _serial)),
      if (decision == 'refund') ...[
        Labeled(context.tr('decision.refundAmount'), child: TextField(controller: _amount, keyboardType: TextInputType.number)),
        Labeled(context.tr('payments.method'), child: DropdownButtonFormField<String>(initialValue: method, items: [for (final m in _methods) DropdownMenuItem(value: m, child: Text(context.tr('payments.methods.$m')))], onChanged: (v) => setState(() => method = v ?? 'cash'))),
        Labeled(context.tr('decision.returnReason'), child: DropdownButtonFormField<String?>(initialValue: returnReasonId, isExpanded: true, items: [DropdownMenuItem<String?>(value: null, child: Text(context.tr('common.dash'))), for (final r in widget.returnReasons) DropdownMenuItem<String?>(value: r.id, child: Text('${r.code} · ${r.names.localized(locale)}', overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => returnReasonId = v))),
      ],
      if (decision == 'reject') Labeled(context.tr('decision.rejectReason'), hint: context.tr('decision.rejectReasonHint'), child: TextField(controller: _reason, maxLines: 3, minLines: 2, maxLength: 500, onChanged: (_) => setState(() {}))),
      Labeled(context.tr('decision.note'), child: TextField(controller: _note, maxLength: 500)),
      BusyButton(
        label: context.tr('decision.apply'),
        danger: decision == 'reject',
        enabled: _valid,
        onPressed: () async {
          final body = <String, dynamic>{'decision': decision, if (_note.text.trim().isNotEmpty) 'note': _note.text.trim()};
          if (decision == 'warranty_repair') body['override'] = goodwill;
          if (decision == 'reject') body['rejectionReason'] = _reason.text.trim();
          if (decision == 'replace' && _serial.text.trim().isNotEmpty) body['replacement'] = {'productId': widget.job.product.id, 'serialNumber': _serial.text.trim()};
          if (decision == 'refund') {
            final amount = double.tryParse(_amount.text.replaceAll(' ', ''));
            if (amount != null && amount > 0) body['refundAmount'] = amount;
            body['refundMethod'] = method;
            if (returnReasonId != null) body['returnReasonId'] = returnReasonId;
          }
          await widget.onSubmit(body);
        },
      ),
    ]);
  }
}

class _PaymentForm extends StatefulWidget {
  const _PaymentForm({required this.balance, required this.onSubmit, this.fiscal});
  final double balance;
  final String? fiscal;
  final Future<bool> Function(Json body) onSubmit;
  @override
  State<_PaymentForm> createState() => _PaymentFormState();
}

class _PaymentFormState extends State<_PaymentForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late final TextEditingController _fiscal = TextEditingController(text: widget.fiscal ?? '');
  String method = 'cash';
  String kind = 'payment';

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SegmentedChoice<String>(value: kind, options: {'payment': context.tr('payments.payment'), 'refund': context.tr('payments.refund')}, onChanged: (v) => setState(() => kind = v)),
      const SizedBox(height: 12),
      Labeled(
        context.tr('payments.amount'),
        child: Row(children: [
          Expanded(child: TextField(controller: _amount, keyboardType: TextInputType.number, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: widget.balance > 0 ? widget.balance.round().toString() : ''))),
          if (widget.balance > 0 && kind == 'payment') Padding(padding: const EdgeInsets.only(left: 8), child: OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)), onPressed: () => setState(() => _amount.text = widget.balance.round().toString()), child: Text(context.tr('payments.fillBalance')))),
        ]),
      ),
      Labeled(context.tr('payments.method'), child: DropdownButtonFormField<String>(initialValue: method, items: [for (final m in _methods) DropdownMenuItem(value: m, child: Text(context.tr('payments.methods.$m')))], onChanged: (v) => setState(() => method = v ?? 'cash'))),
      Labeled(context.tr('payments.fiscal'), hint: context.tr('payments.fiscalHint'), child: TextField(controller: _fiscal)),
      Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 200)),
      BusyButton(
        label: kind == 'refund' ? context.tr('payments.recordRefund') : context.tr('payments.record'),
        enabled: (double.tryParse(_amount.text.replaceAll(' ', '')) ?? 0) > 0,
        onPressed: () async {
          final ok = await widget.onSubmit({
            'amount': double.parse(_amount.text.replaceAll(' ', '')),
            'method': method,
            'kind': kind,
            if (_note.text.trim().isNotEmpty) 'note': _note.text.trim(),
            if (_fiscal.text.trim().isNotEmpty) 'fiscalReceiptNumber': _fiscal.text.trim(),
          });
          if (ok && mounted) {
            _amount.clear();
            _note.clear();
            setState(() {});
          }
        },
      ),
    ]);
  }
}

class _NoteForm extends StatefulWidget {
  const _NoteForm({required this.onSubmit});
  final Future<bool> Function(String text, bool visible) onSubmit;
  @override
  State<_NoteForm> createState() => _NoteFormState();
}

class _NoteFormState extends State<_NoteForm> {
  final _text = TextEditingController();
  bool visible = true;

  static const _templates = ['ready', 'needParts', 'needCall', 'bringReceipt'];

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 8, runSpacing: 4, children: [for (final key in _templates) ActionChip(label: Text(context.tr('notes.templateNames.$key')), onPressed: () => setState(() => _text.text = context.tr('notes.templates.$key')))]),
      const SizedBox(height: 8),
      TextField(controller: _text, maxLines: 3, minLines: 2, maxLength: 1000, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.tr('notes.placeholder'))),
      CheckboxListTile(contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, value: visible, onChanged: (v) => setState(() => visible = v ?? true), title: Text(context.tr('notes.sendToCustomer'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      BusyButton(
        label: visible ? context.tr('notes.send') : context.tr('notes.save'),
        enabled: _text.text.trim().isNotEmpty,
        onPressed: () async {
          final ok = await widget.onSubmit(_text.text.trim(), visible);
          if (ok && mounted) setState(_text.clear);
        },
      ),
    ]);
  }
}
