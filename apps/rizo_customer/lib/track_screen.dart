import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'estimate_card.dart';

/// Check a request without signing in: request number + the phone number on the account.
class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});
  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  final _id = TextEditingController();
  final _phone = TextEditingController();
  final _api = ApiClient();

  Future<void> _find() async {
    final id = normalizeDisplayId(_id.text);
    if (id.isEmpty || _phone.text.trim().isEmpty) return;
    try {
      final r = await _api.post('/api/public/track', body: {'displayId': id, 'phone': _phone.text.trim()});
      final token = asMap(r)['token'].toString();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => TrackResultScreen(token: token)));
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('track.title')), actions: const [LanguageButton()]),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(context.tr('track.hint'), style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 18),
        Labeled(context.tr('common.requestId'), child: TextField(controller: _id, decoration: const InputDecoration(hintText: '#051026010001'))),
        Labeled(context.tr('common.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone)),
        BusyButton(label: context.tr('track.find'), icon: Icons.search, onPressed: _find),
      ]),
    );
  }
}

/// What the public tracking link shows: status, estimate (can be answered here), payment and history.
class TrackResultScreen extends StatefulWidget {
  const TrackResultScreen({super.key, required this.token});
  final String token;
  @override
  State<TrackResultScreen> createState() => _TrackResultScreenState();
}

class _TrackResultScreenState extends State<TrackResultScreen> {
  Json? data;
  Object? error;
  bool loading = true;
  final _api = ApiClient();

  String get _path => '/api/public/track/${widget.token}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get(_path);
      if (mounted) setState(() => data = asMap(asMap(r)['request']));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _respond(String action, PortalEstimate e, Json body) async {
    try {
      final r = await _api.post('$_path/estimate/${e.id}/$action', body: body);
      if (mounted) {
        setState(() => data = asMap(asMap(r)['request']));
        showSnack(context, tr(action == 'approve' ? 'portal.estimateApproved' : 'portal.estimateDeclined'));
      }
    } catch (err) {
      if (mounted) showSnack(context, context.errorText(err), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final d = data;
    return Scaffold(
      appBar: AppBar(title: Text(d == null ? context.tr('track.title') : formatRequestId(asString(d['displayId']))), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: d == null
          ? (loading ? const LoadingView() : EmptyView(title: context.tr('track.notFoundTitle'), body: context.tr('track.notFoundBody')))
          : Builder(builder: (context) {
              final estimate = d['estimate'] is Map ? PortalEstimate(asMap(d['estimate'])) : null;
              final payment = MoneySummary.fromJson(d['payment']);
              final product = Named.fromJson(d['product']);
              final events = asList(d['timeline']).map(TimelineEvent.new).toList();
              final key = '${estimate?.id}-${estimate?.status}';
              return RefreshIndicator(
                onRefresh: _load,
                child: ListView(padding: const EdgeInsets.all(14), children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(product.localized(locale), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(spacing: 6, children: [TypeChip(asString(d['type'])), StatusChip(asString(d['status']), friendly: true), LocationChip(asString(d['locationType']))]),
                        const SizedBox(height: 10),
                        InfoRow(context.tr('common.opened'), formatStamp(asDate(d['createdAt']))),
                        if (d['scheduledAt'] != null) InfoRow(context.tr('portal.visitTime'), formatStamp(asDate(d['scheduledAt']))),
                        if (d['dueBy'] != null) InfoRow(context.tr('portal.dueBy'), formatDate(asString(d['dueBy']))),
                        if (d['technicianFirstName'] != null) InfoRow(context.tr('common.technician'), asString(d['technicianFirstName'])),
                        if (payment.due > 0) InfoRow(context.tr('portal.toPay'), formatMoney(payment.due)),
                      ]),
                    ),
                  ),
                  if (d['canConfirmPickup'] == true) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Brand.greenTint, borderRadius: BorderRadius.circular(14)), child: Text(context.tr('track.readyForPickup'), style: const TextStyle(color: Brand.green, fontWeight: FontWeight.w800)))),
                  if (d['rejectionReason'] != null) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Brand.redTint, borderRadius: BorderRadius.circular(14)), child: Text(context.tr('portal.rejectedBecause', params: {'reason': d['rejectionReason']}), style: const TextStyle(color: Brand.red, fontWeight: FontWeight.w800)))),
                  if (estimate != null) ...[
                    const SizedBox(height: 12),
                    CustomerEstimateCard(key: ValueKey(key), estimate: estimate, onApprove: (ids) => _respond('approve', estimate, {'selectedOptionalLineIds': ids}), onDecline: (reason) => _respond('decline', estimate, {'reason': reason})),
                  ],
                  const SizedBox(height: 12),
                  Section(title: context.tr('detail.timeline'), child: _TrackTimeline(events)),
                  const SizedBox(height: 16),
                  Center(child: Text(context.tr('track.footer'), style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)))),
                ]),
              );
            }),
    );
  }
}

class _TrackTimeline extends StatelessWidget {
  const _TrackTimeline(this.events);
  final List<TimelineEvent> events;
  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return Text(context.tr('timeline.empty'), style: const TextStyle(color: Color(0xFF6B7280)));
    return Column(children: [
      for (final e in events)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.circle, size: 10, color: Brand.purple),
          title: Text(tr(e.titleKey ?? 'timeline.${e.kind}', def: e.title), style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text(formatStamp(e.at)),
        ),
    ]);
  }
}
