import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Key numbers for the chosen period, with the change against the period before.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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

  int? _delta(double current, double? previous) {
    if (previous == null || previous == 0) return null;
    return (((current - previous) / previous) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.dashboard')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SegmentedChoice<String>(value: preset, options: {for (final p in ['week', 'month', 'quarter', 'year']) p: context.tr('reports.preset.$p')}, onChanged: (v) {
            setState(() => preset = v);
            _load();
          }),
          const SizedBox(height: 12),
          if (loading) const LoadingView(),
          if (error != null && d == null) ErrorView(error: error!, onRetry: _load),
          if (d != null) ...[
            LayoutBuilder(builder: (context, c) {
              final cols = c.maxWidth >= 700 ? 4 : 2;
              final cards = [
                _Kpi(context.tr('reports.requests'), formatNumber(d.total('requests')), _delta(d.total('requests'), d.previous?['requests'] is num ? (d.previous!['requests'] as num).toDouble() : null)),
                _Kpi(context.tr('reports.revenue'), formatMoney(d.total('revenue')), _delta(d.total('revenue'), d.previous?['revenue'] is num ? (d.previous!['revenue'] as num).toDouble() : null)),
                _Kpi(context.tr('reports.profit'), formatMoney(d.total('profit')), _delta(d.total('profit'), d.previous?['profit'] is num ? (d.previous!['profit'] as num).toDouble() : null)),
                _Kpi(context.tr('dashboard.avgWork'), formatDurationHours(d.totalOrNull('avgWorkMinutes') == null ? null : d.totalOrNull('avgWorkMinutes')! / 60), null),
                _Kpi(context.tr('reports.avgHours'), formatDurationHours(d.totalOrNull('avgResolutionHours')), null),
                _Kpi(context.tr('reports.avgRating'), d.totalOrNull('avgRating') == null ? context.tr('common.dash') : '★ ${d.total('avgRating').toStringAsFixed(1)} (${d.total('ratingCount').round()})', null),
                _Kpi(context.tr('dashboard.legalOverdue'), formatNumber(d.total('legalOverdue')), null, bad: d.total('legalOverdue') > 0),
                _Kpi(context.tr('dashboard.debt'), formatMoney(d.total('debt')), null, bad: d.total('debt') > 0),
              ];
              return GridView.count(crossAxisCount: cols, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55, children: cards);
            }),
            const SizedBox(height: 12),
            Section(
              title: context.tr('reports.byStatus'),
              child: Column(children: [
                for (final row in d.byStatus.where((r) => asInt(r['count']) > 0))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(width: 130, child: Text(statusLabel(asString(row['status'])), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
                      Expanded(child: _Bar(value: asInt(row['count']).toDouble(), max: d.byStatus.fold<double>(1, (m, r) => asDouble(r['count']) > m ? asDouble(r['count']) : m), color: statusColors(asString(row['status'])).fg)),
                      SizedBox(width: 36, child: Text('${row['count']}', textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w900))),
                    ]),
                  ),
              ]),
            ),
            const SizedBox(height: 12),
            Section(
              title: context.tr('dashboard.topProducts'),
              child: Column(children: [
                for (final p in d.topProducts.take(6)) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(Named.fromJson(p).localized(locale), style: const TextStyle(fontWeight: FontWeight.w700)), trailing: Text('${p['count']}', style: const TextStyle(fontWeight: FontWeight.w900))),
              ]),
            ),
            const SizedBox(height: 12),
            Section(
              title: context.tr('dashboard.warranty'),
              child: Row(children: [
                Expanded(child: _Mini(context.tr('reports.inWarrantyFree'), '${d.warrantySplit['free'] ?? 0}', Brand.green)),
                const SizedBox(width: 10),
                Expanded(child: _Mini(context.tr('reports.paidRepair'), '${d.warrantySplit['paid'] ?? 0}', Brand.orangeText)),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.label, this.value, this.delta, {this.bad = false});
  final String label;
  final String value;
  final int? delta;
  final bool bad;
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Brand.muted), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: bad ? Brand.red : Brand.ink))),
          if (delta != null) Text('${delta! > 0 ? '▲' : (delta! < 0 ? '▼' : '•')} ${delta!.abs()}% ${context.tr('dashboard.vsPrevious')}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: delta! >= 0 ? Brand.green : Brand.red)),
        ]),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.max, required this.color});
  final double value;
  final double max;
  final Color color;
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: max == 0 ? 0 : value / max, minHeight: 10, color: color, backgroundColor: Brand.surfaceAlt));
}

class _Mini extends StatelessWidget {
  const _Mini(this.label, this.value, this.color);
  final String label;
  final String value;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.surfaceSoft, borderRadius: BorderRadius.circular(14)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 12, color: Brand.muted, fontWeight: FontWeight.w700)), Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: color))]),
      );
}
