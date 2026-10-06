import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'request_detail_screen.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key, required this.onNew});
  final VoidCallback onNew;
  @override
  State<RequestsScreen> createState() => RequestsScreenState();
}

class RequestsScreenState extends State<RequestsScreen> {
  List<PortalRequest> items = [];
  Object? error;
  bool loading = true;
  String scope = 'all';
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 40), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void reload() => _load(silent: true);

  Future<void> _load({bool silent = false}) async {
    try {
      final r = await context.read<CustomerSession>().api.get('/api/customer/requests');
      if (mounted) {
        setState(() {
          items = asList(asMap(r)['requests']).map(PortalRequest.new).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final user = context.watch<CustomerSession>().user!;
    final shown = items.where((r) => scope == 'all' || (scope == 'open' ? !isDoneStatus(r.status) && !isTerminalStatus(r.status) : isTerminalStatus(r.status))).toList();
    final pendingEstimates = items.where((r) => r.estimate?.canRespond == true).toList();
    final pendingFeedback = items.where((r) => r.canFeedback).length;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('portal.homeTitle')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: loading
          ? const LoadingView()
          : error != null && items.isEmpty
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(14, 8, 14, 100), children: [
                    Text(context.tr('portal.hello', params: {'name': user.name.split(' ').first}), style: TextStyle(color: Brand.purple, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(context.tr('portal.homeIntro'), style: TextStyle(color: Brand.muted, fontSize: 13)),
                    for (final r in pendingEstimates)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: InkWell(
                          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: r.id))).then((_) => _load(silent: true)),
                          child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Brand.purpleTint, borderRadius: BorderRadius.circular(14)), child: Row(children: [Icon(Icons.request_quote_outlined, color: Brand.purple), const SizedBox(width: 10), Expanded(child: Text(context.tr('portal.estimatePending', params: {'id': formatRequestId(r.displayId)}), style: TextStyle(color: Brand.purple, fontWeight: FontWeight.w800))), Icon(Icons.chevron_right, color: Brand.purple)])),
                        ),
                      ),
                    if (pendingFeedback > 0) Padding(padding: const EdgeInsets.only(top: 12), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Brand.orangeTint, borderRadius: BorderRadius.circular(14)), child: Text(context.tr('portal.pendingFeedback', count: pendingFeedback), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w800)))),
                    const SizedBox(height: 12),
                    SegmentedChoice<String>(value: scope, options: {'all': context.tr('common.all'), 'open': context.tr('mobile.filter.open'), 'done': context.tr('mobile.filter.done')}, onChanged: (v) => setState(() => scope = v)),
                    const SizedBox(height: 12),
                    if (shown.isEmpty)
                      SizedBox(height: 280, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [EmptyView(title: context.tr('portal.emptyTitle'), body: context.tr('portal.emptyBody')), FilledButton(onPressed: widget.onNew, style: FilledButton.styleFrom(minimumSize: const Size(200, 48)), child: Text(context.tr('nav.newRequest')))]))
                    else
                      for (final r in shown)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Card(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: r.id))).then((_) => _load(silent: true)),
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [Text(formatRequestId(r.displayId), style: TextStyle(color: Brand.faint, fontWeight: FontWeight.w800, fontSize: 12)), const Spacer(), Text(formatDateTime(r.createdAt), style: TextStyle(color: Brand.faint, fontSize: 12))]),
                                  Text(r.product.name(locale), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 8),
                                  Wrap(spacing: 6, runSpacing: 6, children: [TypeChip(r.type), StatusChip(r.status, friendly: true), WarrantyChip(r.warrantyStatus)]),
                                  if (r.technicianName != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('portal.technicianLine', params: {'name': r.technicianName}), style: TextStyle(fontSize: 13, color: Brand.muted))),
                                  if (r.estimate?.canRespond == true) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('estimate.status.sent'), style: TextStyle(fontWeight: FontWeight.w800, color: Brand.purple))),
                                ]),
                              ),
                            ),
                          ),
                        ),
                  ]),
                ),
    );
  }
}
