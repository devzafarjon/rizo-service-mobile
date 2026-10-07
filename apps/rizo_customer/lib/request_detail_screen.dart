import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rizo_core/rizo_core.dart';

import 'estimate_card.dart';
import 'feedback_form.dart';
import 'visit_card.dart';

/// One request as the customer sees it: status, estimate to approve, messages, payment, pickup and rating.
class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key, required this.requestId});
  final String requestId;
  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  PortalRequest? request;
  Object? error;
  bool loading = true;
  final _message = TextEditingController();
  Timer? _poll;

  ApiClient get _api => context.read<CustomerSession>().api;
  String get _path => '/api/customer/requests/${widget.requestId}';

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    try {
      final r = await _api.get(_path);
      if (mounted) setState(() => request = PortalRequest(asMap(asMap(r)['request'])));
    } catch (e) {
      if (mounted && !silent) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _apply(Object? response) {
    final r = asMap(asMap(response)['request']);
    if (r.isNotEmpty && mounted) setState(() => request = PortalRequest(r));
  }

  Future<void> _call(Future<Object?> Function() action, {String? success}) async {
    try {
      final r = await action();
      _apply(r);
      if (mounted && success != null) showSnack(context, success);
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Scaffold(
      appBar: AppBar(title: Text(r == null ? context.tr('mobile.request') : formatRequestId(r.displayId)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: r == null ? (loading ? const LoadingView() : ErrorView(error: error ?? ApiException(404, 'x', code: 'requestNotFound'), onRetry: _load)) : _body(r),
    );
  }

  Widget _body(PortalRequest r) {
    final locale = context.watch<Translator>().locale;
    final trackUrl = '${AppConfig.webUrl}/t/${r.trackingToken}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, padding: const EdgeInsets.all(14), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.product.name(locale), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              Text('${r.product.sku}${r.serialNumber != null ? ' · ${context.tr('serial.label')}: ${r.serialNumber}' : ''}', style: TextStyle(color: Brand.muted)),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, children: [TypeChip(r.type), StatusChip(r.status, friendly: true), WarrantyChip(r.warrantyStatus), LocationChip(r.locationType)]),
              const SizedBox(height: 12),
              Text(r.issueDescription),
            ]),
          ),
        ),
        if (r.enRouteAt != null && !isTerminalStatus(r.status)) _banner(Icons.local_shipping_outlined, context.tr('portal.technicianOnTheWay', params: {'name': r.technicianName ?? ''}), Brand.orangeTint, Brand.orangeText),
        VisitCard(request: r, api: _api, onChanged: (response, {String? success}) async {
          _apply(response);
          if (mounted && success != null) showSnack(context, success);
          await _load(silent: true);
        }),
        PayCard(request: r, api: _api),
        if (r.status == 'rejected' && r.rejectionReason != null) _banner(Icons.block, context.tr('portal.rejectedBecause', params: {'reason': r.rejectionReason}), Brand.redTint, Brand.red),
        if (r.status == 'awaiting_parts') _banner(Icons.inventory_2_outlined, context.tr('portal.waitingParts'), Brand.amberTint, Brand.amberText),
        if (r.estimate != null) ...[
          const SizedBox(height: 12),
          CustomerEstimateCard(
            key: ValueKey('${r.estimate!.id}-${r.estimate!.status}'),
            estimate: r.estimate!,
            onApprove: (ids) => _call(() => _api.post('$_path/estimates/${r.estimate!.id}/approve', body: {'selectedOptionalLineIds': ids}), success: tr('portal.estimateApproved')),
            onDecline: (reason) => _call(() => _api.post('$_path/estimates/${r.estimate!.id}/decline', body: {'reason': reason}), success: tr('portal.estimateDeclined')),
          ),
        ],
        const SizedBox(height: 12),
        Section(
          child: Column(children: [
            InfoRow(context.tr('common.opened'), formatDateTime(r.createdAt)),
            if (r.dueBy != null) InfoRow(context.tr('portal.dueBy'), formatDate(r.dueBy!.toIso8601String())),
            InfoRow(context.tr('common.completed'), formatDateTime(r.completedAt)),
            InfoRow(context.tr('common.technician'), r.technicianName ?? context.tr('portal.waitingAssignment')),
            if (r.serviceCenter != null)
              InfoRow(context.tr('centers.center'), null, valueWidget: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(r.serviceCenter!.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)), Text('${r.serviceCenter!.address}${r.serviceCenter!.workingHours != null ? ' · ${r.serviceCenter!.workingHours}' : ''}', style: TextStyle(fontSize: 12, color: Brand.muted)), if (r.serviceCenter!.phone != null) PhoneLink(r.serviceCenter!.phone!)])),
            if (r.saleInvoice != null) InfoRow(context.tr('common.invoice'), '${r.saleInvoice} · ${r.saleWarrantyStatus == 'in_warranty' ? context.tr('portal.inWarrantyUntil') : context.tr('portal.expired')} ${r.saleWarrantyExpiry != null ? formatDate(r.saleWarrantyExpiry!) : ''}'),
            if (r.repairWarrantyUntil != null) InfoRow(context.tr('portal.repairWarranty'), context.tr('portal.repairWarrantyUntil', params: {'date': formatDate(r.repairWarrantyUntil!)})),
            if (r.payment.due > 0) InfoRow(context.tr('portal.toPay'), '${formatMoney(r.payment.due)}${r.payment.paid > 0 ? ' · ${context.tr('payments.paid')}: ${formatMoney(r.payment.paid)}' : ''}${r.payment.balance > 0 && r.payment.paid > 0 ? ' · ${context.tr('payments.balance')}: ${formatMoney(r.payment.balance)}' : ''}'),
          ]),
        ),
        if (r.canConfirmPickup) ...[const SizedBox(height: 12), PickupConfirmCard(customer: true, onConfirm: (sig) => _call(() => _api.post('$_path/pickup', body: {'signature': sig}), success: tr('pickup.saved')))]
        else if (r.pickupConfirmedAt != null && r.locationType == 'in_shop') Padding(padding: const EdgeInsets.only(top: 12), child: Text(context.tr('pickup.already'), style: TextStyle(color: Brand.green, fontWeight: FontWeight.w900))),
        const SizedBox(height: 12),
        Section(
          title: context.tr('portal.messages'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (r.messages.isEmpty) Text(context.tr('portal.noMessages'), style: TextStyle(color: Brand.muted)),
            for (final m in r.messages)
              Align(
                alignment: m.fromCustomer ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: m.fromCustomer ? Brand.purpleTint : Brand.surfaceAlt, borderRadius: BorderRadius.circular(14)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.text), const SizedBox(height: 4), Text('${m.fromCustomer ? context.tr('portal.you') : context.tr('portal.service')} · ${formatStamp(m.createdAt)}', style: TextStyle(fontSize: 11, color: Brand.muted))]),
                ),
              ),
            if (r.status != 'cancelled') ...[
              TextField(controller: _message, maxLines: 3, minLines: 1, maxLength: 1000, decoration: InputDecoration(hintText: context.tr('portal.messagePlaceholder'))),
              BusyButton(
                label: context.tr('portal.sendMessage'),
                icon: Icons.send_outlined,
                onPressed: () async {
                  final text = _message.text.trim();
                  if (text.isEmpty) return;
                  await _call(() => _api.post('$_path/comments', body: {'text': text}));
                  if (mounted) _message.clear();
                },
              ),
            ],
          ]),
        ),
        const SizedBox(height: 12),
        FeedbackForm(request: r, onSubmit: (rating, tags, comment) => _call(() => _api.post('$_path/feedback', body: {'rating': rating, 'tags': tags, if (comment.isNotEmpty) 'comment': comment}), success: tr('feedback.thanks'))),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: trackUrl));
            if (mounted) showSnack(context, tr('detail.linkCopied'));
          },
          icon: const Icon(Icons.link),
          label: Text(context.tr('portal.shareLink')),
        ),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _banner(IconData icon, String text, Color bg, Color fg) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(icon, color: fg), const SizedBox(width: 10), Expanded(child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w800)))])),
      );
}
