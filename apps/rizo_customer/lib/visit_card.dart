import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// The visit window of a request: confirm it, move it or withdraw the request; also the technician's arrival estimate.
class VisitCard extends StatelessWidget {
  const VisitCard({super.key, required this.request, required this.api, required this.onChanged});
  final PortalRequest request;
  final ApiClient api;
  final Future<void> Function(Object? response, {String? success}) onChanged;

  String get _path => '/api/customer/requests/${request.id}';

  Future<void> _book(BuildContext context) async {
    final scheduled = request.scheduledAt?.toLocal();
    final choice = await pickVisitSlot(
      context,
      initialDate: scheduled == null ? null : '${scheduled.year.toString().padLeft(4, '0')}-${scheduled.month.toString().padLeft(2, '0')}-${scheduled.day.toString().padLeft(2, '0')}',
      loadSlots: (date) async => asList(asMap(await api.get('/api/customer/visit-slots', query: {'date': date, 'requestId': request.id})) ['slots']).map(VisitSlot.new).toList(),
    );
    if (choice == null || !context.mounted) return;
    final saved = context.tr('visit.saved');
    try {
      await onChanged(await api.post('$_path/visit', body: {'date': choice.date, 'slot': choice.slot}), success: saved);
    } catch (e) {
      if (context.mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final visit = request.visit;
    final scheduled = request.scheduledAt;
    if (!visit.canBook && scheduled == null && !visit.canCancel) return const SizedBox.shrink();
    final canMove = scheduled != null ? visit.canReschedule : visit.canBook;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Section(
        title: context.tr('visit.title'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (scheduled != null)
            Wrap(spacing: 10, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(visit.slot != null ? '${formatDate(scheduled.toLocal().toIso8601String())} · ${visit.slot!.replaceFirst('-', ' – ')}' : formatStamp(scheduled), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              Pill(visit.confirmed ? context.tr('visit.confirmed') : context.tr('visit.notConfirmed'), color: visit.confirmed ? Brand.green : Brand.amberText, background: visit.confirmed ? Brand.greenTint : Brand.amberTint),
            ])
          else
            Text(context.tr('visit.noneCustomer'), style: TextStyle(color: Brand.muted)),
          if (request.etaMinutes != null && request.enRouteAt != null)
            Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('visit.eta', params: {'minutes': request.etaMinutes}), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w800))),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (scheduled != null && !visit.confirmed)
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () async {
                  final note = context.tr('visit.confirmedNote');
                  try {
                    await onChanged(await api.post('$_path/visit/confirm'), success: note);
                  } catch (e) {
                    if (context.mounted) showSnack(context, context.errorText(e), error: true);
                  }
                },
                child: Text(context.tr('visit.confirmButton')),
              ),
            if (canMove)
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _book(context), child: Text(scheduled != null ? context.tr('visit.move') : context.tr('visit.book'))),
            if (visit.canCancel)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Brand.red, minimumSize: const Size(0, 44)),
                onPressed: () async {
                  final done = context.tr('visit.cancelled');
                  if (!await confirmDialog(context, context.tr('visit.cancelRequest'), body: context.tr('visit.cancelConfirm'), confirmLabel: context.tr('visit.cancelRequest'))) return;
                  try {
                    await onChanged(await api.post('$_path/cancel', body: {'reason': ''}), success: done);
                  } catch (e) {
                    if (context.mounted) showSnack(context, context.errorText(e), error: true);
                  }
                },
                child: Text(context.tr('visit.cancelRequest')),
              ),
          ]),
          if (scheduled != null && !visit.canReschedule && visit.canBook) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('visit.callToMove'), style: TextStyle(color: Brand.muted, fontSize: 12))),
        ]),
      ),
    );
  }
}

/// Payme / Click buttons for what is still owed, when the service has switched them on.
class PayCard extends StatefulWidget {
  const PayCard({super.key, required this.request, required this.api});
  final PortalRequest request;
  final ApiClient api;
  @override
  State<PayCard> createState() => _PayCardState();
}

class _PayCardState extends State<PayCard> {
  Json? links;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PayCard old) {
    super.didUpdateWidget(old);
    if (old.request.payment.balance != widget.request.payment.balance) _load();
  }

  Future<void> _load() async {
    if (widget.request.payment.balance <= 0) {
      if (mounted) setState(() => links = null);
      return;
    }
    try {
      final data = asMap(await widget.api.get('/api/customer/requests/${widget.request.id}/pay-links'));
      if (mounted) setState(() => links = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final data = links;
    if (data == null || data['enabled'] != true) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Section(
        title: context.tr('pay.title'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('pay.body', params: {'amount': formatMoney(asDouble(data['amount']))})),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (data['payme'] != null) FilledButton(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => openUri(context, Uri.parse(data['payme'].toString())), child: const Text('Payme')),
            if (data['click'] != null) OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => openUri(context, Uri.parse(data['click'].toString())), child: const Text('Click')),
          ]),
          const SizedBox(height: 8),
          Text(context.tr('pay.note'), style: TextStyle(color: Brand.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}
