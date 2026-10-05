import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// What the technician has earned in the chosen period: a share of the labour per job, a fixed amount per job, bonuses and penalties.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});
  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  String preset = 'month';
  Json? data;
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await context.read<StaffSession>().api.get('/api/staff/my-jobs/earnings', query: {'preset': preset});
      if (mounted) setState(() => data = asMap(result));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tech = asMap(data?['technician']);
    final jobs = asList(data?['jobs']);
    final adjustments = asList(data?['adjustments']);
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('payroll.myTitle'))),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(16), children: [
          SegmentedChoice<String>(value: preset, options: {for (final p in ['week', 'month', 'quarter', 'year']) p: context.tr('reports.preset.$p')}, onChanged: (v) {
            setState(() => preset = v);
            _load();
          }),
          const SizedBox(height: 12),
          if (loading && data == null) const LoadingView(),
          if (error != null && data == null) ErrorView(error: error!, onRetry: _load),
          if (data != null) ...[
            Text(context.tr('payroll.myIntro', params: {'percent': tech['payPercent'], 'fixed': formatMoney(asDouble(tech['payFixedPerJob']))}), style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Brand.purple, borderRadius: BorderRadius.circular(18)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr('payroll.total'), style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
                Text(formatMoney(asDouble(data!['total'])), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900)),
              ]),
            ),
            const SizedBox(height: 12),
            Section(
              title: context.tr('payroll.jobs'),
              child: jobs.isEmpty
                  ? Text(context.tr('payroll.noJobs'), style: const TextStyle(color: Color(0xFF6B7280)))
                  : Column(children: [
                      for (final job in jobs)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(formatRequestId(asString(job['displayId'])), style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${job['completedAt'] != null ? formatDate(asString(job['completedAt'])) : ''} · ${context.tr('payroll.labor')}: ${formatMoney(asDouble(job['labor']))}'),
                          trailing: Text(formatMoney(asDouble(job['earned'])), style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                    ]),
            ),
            if (adjustments.isNotEmpty) ...[
              const SizedBox(height: 12),
              Section(
                title: context.tr('payroll.adjustments'),
                child: Column(children: [
                  for (final a in adjustments)
                    ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(asString(a['reason'])), trailing: Text(formatMoney(asDouble(a['amount'])), style: TextStyle(fontWeight: FontWeight.w900, color: asDouble(a['amount']) < 0 ? Brand.red : Brand.green))),
                ]),
              ),
            ],
          ],
        ]),
      ),
    );
  }
}
