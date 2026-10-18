import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// First-time fix, callbacks, callback cost and waiting for parts: the service quality that used to sit on the first screen.
class ServiceQualityScreen extends StatefulWidget {
  const ServiceQualityScreen({super.key});
  @override
  State<ServiceQualityScreen> createState() => _ServiceQualityScreenState();
}

class _ServiceQualityScreenState extends State<ServiceQualityScreen> {
  String preset = 'month';
  DashboardData? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = data == null;
      error = null;
    });
    try {
      final result = await context.read<StaffSession>().api.get('/api/staff/reports/dashboard', query: {'preset': preset});
      if (mounted) setState(() => data = DashboardData(asMap(result)));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Widget _card(String label, String value, {Color? color}) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.muted)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color ?? Brand.ink)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.8);
    final d = data;
    final s = d?.service ?? const <String, dynamic>{};
    String pct(Object? v) => v is num ? '$v%' : tr('common.dash');
    final ftf = s['firstTimeFixRate'];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reports.nav.service')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('reports.nav.serviceBody'), style: TextStyle(color: Brand.muted, fontSize: 13))),
          SegmentedChoice<String>(value: preset, options: {for (final p in ['week', 'month', 'quarter', 'year']) p: context.tr('reports.preset.$p')}, onChanged: (v) {
            setState(() => preset = v);
            _load();
          }),
          const SizedBox(height: 12),
          if (loading) const LoadingView(),
          if (error != null && d == null) ErrorView(error: error!, onRetry: _load),
          if (d != null) ...[
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.35 / textScale, children: [
              _card(context.tr('dashboard.ftf'), pct(ftf), color: ftf is num && ftf < 70 ? Brand.red : Brand.green),
              _card(context.tr('dashboard.callbacks'), pct(s['callbackRate']), color: Brand.orangeText),
              _card(context.tr('dashboard.callbackCost'), formatMoney(asDouble(s['callbackCost'])), color: asDouble(s['callbackCost']) > 0 ? Brand.red : null),
              _card(context.tr('dashboard.partsWait'), formatDurationHours(s['avgPartsWaitHours'] is num ? (s['avgPartsWaitHours'] as num).toDouble() : null), color: Brand.orangeText),
            ]),
            Padding(padding: const EdgeInsets.only(top: 10), child: Text(context.tr('dashboard.ftfHint'), style: TextStyle(color: Brand.muted, fontSize: 12))),
            const SizedBox(height: 12),
            GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.95 / textScale, children: [
              _card(context.tr('reports.requests'), formatNumber(d.total('requests'))),
              _card(context.tr('reports.avgHours'), formatDurationHours(d.totalOrNull('avgResolutionHours'))),
              _card(context.tr('reports.avgRating'), d.totalOrNull('avgRating') == null ? context.tr('common.dash') : '★ ${d.total('avgRating').toStringAsFixed(1)}'),
            ]),
          ],
        ]),
      ),
    );
  }
}
