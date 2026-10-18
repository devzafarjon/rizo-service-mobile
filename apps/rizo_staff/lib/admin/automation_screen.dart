import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'request_detail_screen.dart';

const _icons = {'deadline_watch': Icons.shield_outlined, 'daily_report': Icons.description_outlined, 'weekly_digest': Icons.calendar_month_outlined, 'payroll_statements': Icons.account_balance_wallet_outlined};
const _enabledKey = {'deadline_watch': 'deadlineEnabled', 'daily_report': 'dailyEnabled', 'weekly_digest': 'weeklyEnabled', 'payroll_statements': 'payrollEnabled'};

String _time(num hour) => '${hour.floor().toString().padLeft(2, '0')}:${hour % 1 != 0 ? '30' : '00'}';

String _scheduleText(Json schedule) {
  final hour = schedule['hour'] is num ? schedule['hour'] as num : 0;
  return switch (schedule['type']) {
    'minutely' => tr('auto.schedule.minutely'),
    'daily' => tr('auto.schedule.daily', params: {'time': _time(hour)}),
    'weekly' => tr('auto.schedule.weekly', params: {'time': _time(hour)}),
    _ => tr('auto.schedule.monthly', params: {'time': _time(hour)}),
  };
}

num _n(Object? v) => v is num ? v : 0;

String _resultText(Json run) {
  if (run['ok'] != true) return tr('auto.result.failed', params: {'error': run['error'] ?? ''});
  final s = asMap(run['summary']);
  switch (run['jobKey']) {
    case 'deadline_watch':
      return s['skipped'] == true ? tr('auto.result.off') : tr('auto.result.deadline', params: {'atRisk': _n(s['atRisk']), 'warned': _n(s['warned'])});
    case 'daily_report':
      return tr('auto.result.daily', params: {'created': _n(s['created']), 'finished': _n(s['finished']), 'open': _n(s['open']), 'overdue': _n(s['overdue'])});
    case 'weekly_digest':
      return tr('auto.result.weekly', params: {'created': _n(s['created']), 'finished': _n(s['finished']), 'open': _n(s['open']), 'overdue': _n(s['overdue'])});
    case 'payroll_statements':
      return tr('auto.result.payroll', params: {'technicians': _n(s['technicians']), 'total': formatMoney(_n(s['total']))});
  }
  return '';
}

/// What the system does by itself: deadline warnings, owner reports and pay statements, each with a "Run now" button (admin).
class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});
  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen> {
  Json settings = {};
  List<Json> jobs = [];
  List<Json> atRisk = [];
  List<Json> runs = [];
  List<Json> statements = [];
  Object? error;
  bool loading = true;
  String? running;
  final _percent = TextEditingController();
  final _legal = TextEditingController();
  final _hour = TextEditingController();

  @override
  void dispose() {
    _percent.dispose();
    _legal.dispose();
    _hour.dispose();
    super.dispose();
  }
  String payrollPeriod = 'weekly';

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.get('/api/staff/auto-jobs'), _api.get('/api/staff/auto-jobs/at-risk'), _api.get('/api/staff/auto-jobs/history'), _api.get('/api/staff/auto-jobs/statements')]);
      if (!mounted) return;
      final overview = asMap(results[0]);
      setState(() {
        settings = asMap(overview['settings']);
        jobs = asList(overview['jobs']);
        atRisk = asList(asMap(results[1])['items']);
        runs = asList(asMap(results[2])['runs']);
        statements = asList(asMap(results[3])['statements']);
        _percent.text = '${_n(settings['deadlineWarningPercent'])}';
        _legal.text = '${_n(settings['legalWarningDays'])}';
        _hour.text = '${_n(settings['dailyReportHour'])}';
        payrollPeriod = settings['payrollPeriod'] == 'monthly' ? 'monthly' : 'weekly';
        error = null;
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = e; loading = false; });
    }
  }

  Future<void> _saveSettings(Json body) async {
    try {
      await _api.patch('/api/staff/auto-jobs/settings', body: body);
      if (mounted) showSnack(context, tr('catalog.settingsSaved'));
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  Future<void> _runNow(String key) async {
    setState(() => running = key);
    try {
      final run = asMap(asMap(await _api.post('/api/staff/auto-jobs/$key/run'))['run']);
      if (mounted) showSnack(context, run['ok'] == true ? tr('auto.ranOk', params: {'result': _resultText(run)}) : tr('auto.result.failed', params: {'error': run['error'] ?? ''}), error: run['ok'] != true);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    } finally {
      if (mounted) setState(() => running = null);
    }
  }

  Widget _jobCard(Json job) {
    final key = asString(job['key']);
    final last = job['lastRun'] is Map ? asMap(job['lastRun']) : null;
    final enabledField = _enabledKey[key]!;
    return Section(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Brand.purpleTint, borderRadius: BorderRadius.circular(12)), child: Icon(_icons[key], color: Brand.purple)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(context.tr('auto.job.$key.title'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
                Pill(job['enabled'] == true ? context.tr('auto.on') : context.tr('auto.off'), color: job['enabled'] == true ? Brand.green : Brand.muted, background: job['enabled'] == true ? Brand.greenTint : Brand.surfaceAlt),
              ]),
              const SizedBox(height: 4),
              Text(context.tr('auto.job.$key.body'), style: TextStyle(color: Brand.subtle, fontSize: 13)),
              const SizedBox(height: 6),
              Text(_scheduleText(asMap(job['schedule'])), style: TextStyle(color: Brand.muted, fontWeight: FontWeight.w700, fontSize: 12)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Brand.surfaceAlt, borderRadius: BorderRadius.circular(12)),
          child: last == null
              ? Text(context.tr('auto.never'), style: TextStyle(color: Brand.muted))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${context.tr('auto.lastRun')}: ${formatDateTime(DateTime.tryParse(asString(last['startedAt'])))} · ${context.tr('auto.trigger.${last['trigger']}')}${last['ranByName'] != null ? ' · ${last['ranByName']}' : ''}', style: TextStyle(color: Brand.muted, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(_resultText(last), style: TextStyle(fontWeight: FontWeight.w800, color: last['ok'] == true ? Brand.ink : Brand.red)),
                ]),
        ),
        if (job['overdueSince'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('auto.catchUp'), style: TextStyle(color: Brand.amberText, fontWeight: FontWeight.w700, fontSize: 12))),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(child: SwitchListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text(context.tr('auto.enabled'), style: const TextStyle(fontWeight: FontWeight.w700)), value: settings[enabledField] == true, onChanged: (v) => _saveSettings({enabledField: v}))),
          const SizedBox(width: 8),
          FilledButton.icon(style: FilledButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: running != null ? null : () => _runNow(key), icon: running == key ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.play_arrow_rounded), label: Text(context.tr('auto.runNow'))),
        ]),
      ]),
    );
  }

  Widget _settingsCard() {
    Widget number(String label, String hint, TextEditingController controller) => Labeled(label, hint: hint, child: TextField(controller: controller, keyboardType: TextInputType.number));
    return Section(
      title: context.tr('auto.settings.title'),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        number(context.tr('auto.settings.percent'), context.tr('auto.settings.percentHint'), _percent),
        number(context.tr('auto.settings.legalDays'), context.tr('auto.settings.legalDaysHint'), _legal),
        number(context.tr('auto.settings.dailyHour'), context.tr('auto.settings.dailyHourHint'), _hour),
        Labeled(context.tr('auto.settings.payrollPeriod'), hint: context.tr('auto.settings.payrollPeriodHint'), child: SegmentedChoice<String>(value: payrollPeriod, options: {'weekly': context.tr('auto.settings.weekly'), 'monthly': context.tr('auto.settings.monthly')}, onChanged: (v) => setState(() => payrollPeriod = v))),
        BusyButton(
          label: context.tr('common.save'),
          onPressed: () => _saveSettings({'deadlineWarningPercent': int.tryParse(_percent.text) ?? 25, 'legalWarningDays': int.tryParse(_legal.text) ?? 3, 'dailyReportHour': int.tryParse(_hour.text) ?? 18, 'payrollPeriod': payrollPeriod}),
        ),
      ]),
    );
  }

  Widget _atRiskSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(context.tr('auto.atRisk.title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(context.tr('auto.atRisk.intro', params: {'percent': _n(settings['deadlineWarningPercent']), 'days': _n(settings['legalWarningDays'])}), style: TextStyle(color: Brand.muted, fontSize: 12))),
      if (atRisk.isEmpty) Section(child: Column(children: [Text(context.tr('auto.atRisk.emptyTitle'), style: const TextStyle(fontWeight: FontWeight.w800)), Text(context.tr('auto.atRisk.emptyBody'), style: TextStyle(color: Brand.muted))])),
      for (final item in atRisk)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('${formatRequestId(asString(item['displayId']))} · ${item['product']}', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${asMap(item['technician'])['name'] ?? context.tr('auto.atRisk.unassigned')} · ${context.tr('auto.atRisk.kinds.${item['kind']}')}'),
            trailing: Text(formatDurationMs(_n(item['remainingMs']).toInt()), style: const TextStyle(fontWeight: FontWeight.w900)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: asString(item['id'])))),
          ),
        ),
    ]);
  }

  Widget _reports() {
    final reports = runs.where((r) => (r['jobKey'] == 'daily_report' || r['jobKey'] == 'weekly_digest') && r['ok'] == true && r['summary'] is Map).take(6).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(context.tr('auto.reports.title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(context.tr('auto.reports.intro'), style: TextStyle(color: Brand.muted, fontSize: 12))),
      if (reports.isEmpty) Padding(padding: const EdgeInsets.all(8), child: Text(context.tr('auto.never'), style: TextStyle(color: Brand.muted))),
      for (final run in reports) _reportCard(run),
    ]);
  }

  Widget _reportCard(Json run) {
    final s = asMap(run['summary']);
    final daily = run['jobKey'] == 'daily_report';
    final cells = <(String, String)>[
      (context.tr('auto.reports.created'), '${_n(s['created'])}'),
      (context.tr('auto.reports.finished'), '${_n(s['finished'])}'),
      (context.tr('auto.reports.open'), '${_n(s['open'])}'),
      (context.tr('auto.reports.overdue'), '${_n(s['overdue'])}'),
      if (daily) ...[(context.tr('auto.reports.atRisk'), '${_n(s['atRisk'])}'), (context.tr('auto.reports.partsWaiting'), '${_n(s['partsWaiting'])}'), (context.tr('auto.reports.collected'), formatMoney(_n(s['collected'])))] else (context.tr('auto.reports.revenue'), formatMoney(_n(s['revenue']))),
      (context.tr('auto.reports.rating'), s['avgRating'] is num ? (s['avgRating'] as num).toStringAsFixed(1) : '—'),
    ];
    final top = s['topTechnician'] is Map ? asMap(s['topTechnician']) : null;
    return Section(
      title: daily ? context.tr('auto.reports.dailyTitle', params: {'date': asString(s['date'])}) : context.tr('auto.reports.weeklyTitle', params: {'from': asString(s['from']), 'to': asString(s['to'])}),
      trailing: Text(context.tr('auto.trigger.${run['trigger']}'), style: TextStyle(color: Brand.muted, fontSize: 12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 18, runSpacing: 8, children: [
          for (final (label, value) in cells) SizedBox(width: 130, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(color: Brand.muted, fontSize: 11)), Text(value, style: const TextStyle(fontWeight: FontWeight.w900))])),
        ]),
        if (daily && top != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('auto.reports.top', params: {'name': top['name'] ?? '', 'count': _n(top['done'])}), style: TextStyle(color: Brand.subtle, fontSize: 12))),
      ]),
    );
  }

  Widget _statementsSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 4), child: Text(context.tr('auto.statements.title'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))),
      Padding(padding: const EdgeInsets.fromLTRB(4, 0, 4, 8), child: Text(context.tr('auto.statements.intro'), style: TextStyle(color: Brand.muted, fontSize: 12))),
      if (statements.isEmpty) Section(child: Column(children: [Text(context.tr('auto.statements.emptyTitle'), style: const TextStyle(fontWeight: FontWeight.w800)), Text(context.tr('auto.statements.emptyBody'), style: TextStyle(color: Brand.muted), textAlign: TextAlign.center)])),
      for (final row in statements)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text(asString(asMap(row['technician'])['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${formatDate(asString(row['from']))} – ${formatDate(asString(row['to']))}${row['kind'] == 'manual' ? ' · ${context.tr('auto.statements.interim')}' : ''}\n${context.tr('auto.statements.jobs')}: ${_n(row['jobs'])} · ${context.tr('payroll.jobsTotal')}: ${formatMoney(_n(row['jobsTotal']))} · ${context.tr('payroll.adjustments')}: ${formatMoney(_n(row['adjustmentsTotal']))}'),
            isThreeLine: true,
            trailing: Text(formatMoney(_n(row['total'])), style: const TextStyle(fontWeight: FontWeight.w900)),
          ),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('auto.title'))),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('auto.intro'), style: TextStyle(color: Brand.muted, fontSize: 13))),
                    for (final job in jobs) Padding(padding: const EdgeInsets.only(bottom: 10), child: _jobCard(job)),
                    _settingsCard(),
                    _atRiskSection(),
                    _reports(),
                    _statementsSection(),
                    const SizedBox(height: 30),
                  ]),
                ),
    );
  }
}
