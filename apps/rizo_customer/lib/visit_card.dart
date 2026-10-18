import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// The visit window of a request: confirm it, move it or withdraw the request; also the technician's arrival estimate.
class VisitCard extends StatefulWidget {
  const VisitCard({super.key, required this.request, required this.api, required this.onChanged});
  final PortalRequest request;
  final ApiClient api;
  final Future<void> Function(Object? response, {String? success}) onChanged;
  @override
  State<VisitCard> createState() => _VisitCardState();
}

class _VisitCardState extends State<VisitCard> {
  bool _busy = false;

  PortalRequest get request => widget.request;
  ApiClient get api => widget.api;
  Future<void> Function(Object? response, {String? success}) get onChanged => widget.onChanged;
  String get _path => '/api/customer/requests/${request.id}';

  /// One action at a time: a second tap while the first is in flight would book, confirm or cancel twice.
  Future<void> _guard(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _book(BuildContext context) async {
    final scheduled = request.scheduledAt?.toLocal();
    final choice = await pickVisitSlot(
      context,
      initialDate: scheduled == null ? null : '${scheduled.year.toString().padLeft(4, '0')}-${scheduled.month.toString().padLeft(2, '0')}-${scheduled.day.toString().padLeft(2, '0')}',
      loadSlots: (date) async => asList(asMap(await api.get('/api/customer/visit-slots', query: {'date': date, 'requestId': request.id})) ['slots']).map(VisitSlot.new).toList(),
    );
    if (choice == null || !mounted) return;
    final saved = tr('visit.saved');
    try {
      await onChanged(await api.post('$_path/visit', body: {'date': choice.date, 'slot': choice.slot}), success: saved);
    } catch (e) {
      if (mounted) showSnack(this.context, Translator.I.errorMessage(e), error: true);
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
                onPressed: _busy
                    ? null
                    : () => _guard(() async {
                          final note = tr('visit.confirmedNote');
                          try {
                            await onChanged(await api.post('$_path/visit/confirm'), success: note);
                          } catch (e) {
                            if (mounted) showSnack(this.context, Translator.I.errorMessage(e), error: true);
                          }
                        }),
                child: Text(context.tr('visit.confirmButton')),
              ),
            if (canMove)
              OutlinedButton(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: _busy ? null : () => _guard(() => _book(context)), child: Text(scheduled != null ? context.tr('visit.move') : context.tr('visit.book'))),
            if (visit.canCancel)
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Brand.red, minimumSize: const Size(0, 44)),
                onPressed: _busy
                    ? null
                    : () => _guard(() async {
                          final done = tr('visit.cancelled');
                          if (!await confirmDialog(context, tr('visit.cancelRequest'), body: tr('visit.cancelConfirm'), confirmLabel: tr('visit.cancelRequest'))) return;
                          try {
                            await onChanged(await api.post('$_path/cancel', body: {'reason': ''}), success: done);
                          } catch (e) {
                            if (mounted) showSnack(this.context, Translator.I.errorMessage(e), error: true);
                          }
                        }),
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
    if (old.request.id != widget.request.id || old.request.status != widget.request.status || old.request.payment.balance != widget.request.payment.balance) _load();
  }

  Future<void> _load() async {
    if (widget.request.payment.balance <= 0) {
      if (mounted) setState(() => links = null);
      return;
    }
    try {
      final data = asMap(await widget.api.get('/api/customer/requests/${widget.request.id}/pay-links'));
      if (mounted) setState(() => links = data);
    } catch (_) {
      if (mounted) setState(() => links = null);
    }
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
            if (data['payme'] != null) _PayButton(provider: 'payme', onTap: () => openUri(context, Uri.parse(data['payme'].toString()))),
            if (data['click'] != null) _PayButton(provider: 'click', onTap: () => openUri(context, Uri.parse(data['click'].toString()))),
          ]),
          if (data['placeholder'] == true) ...[
            const SizedBox(height: 6),
            Text(context.tr('pay.placeholder'), style: TextStyle(color: Brand.muted, fontSize: 12)),
          ],
          const SizedBox(height: 8),
          Text(context.tr('pay.note'), style: TextStyle(color: Brand.muted, fontSize: 12)),
        ]),
      ),
    );
  }
}

/// Payme / Click button with the provider's colour mark (a letter mark, not the official logo).
class _PayButton extends StatelessWidget {
  const _PayButton({required this.provider, required this.onTap});
  final String provider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isPayme = provider == 'payme';
    final color = isPayme ? const Color(0xFF00B8B8) : const Color(0xFF0A9BE6);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 14)),
      onPressed: onTap,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(6)),
          child: Text(isPayme ? 'P' : 'C', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 8),
        Text(isPayme ? 'Payme' : 'Click'),
      ]),
    );
  }
}
