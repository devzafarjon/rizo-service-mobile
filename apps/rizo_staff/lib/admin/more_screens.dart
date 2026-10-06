import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'request_detail_screen.dart';

/// Messages for the dispatcher: overdue jobs, new customer messages, estimate answers, low stock.
class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});
  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  List<AlertItem> alerts = [];
  List<Json> lowStock = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = asMap(await _api.get('/api/staff/alerts'));
      if (mounted) {
        setState(() {
          alerts = asList(result['notifications']).map(AlertItem.new).toList();
          lowStock = asList(result['lowStock']);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  String _text(AlertItem a) {
    final params = {...a.params, 'id': a.params['displayId'] == null ? '' : formatRequestId(a.params['displayId'].toString())};
    if (a.code == null) return a.message;
    return tr('notify.${a.code}', params: params, def: a.message);
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('alerts.title')), actions: [
        TextButton(
          onPressed: alerts.any((a) => !a.isRead)
              ? () async {
                  await _api.patch('/api/staff/alerts/read-all');
                  _load();
                }
              : null,
          child: Text(context.tr('mobile.markAllRead')),
        ),
      ]),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(12), children: [
                    if (lowStock.isNotEmpty)
                      Section(
                        title: context.tr('alerts.lowStock'),
                        child: Column(children: [for (final p in lowStock) ListTile(dense: true, contentPadding: EdgeInsets.zero, title: Text(Named.fromJson(p).localized(locale), style: const TextStyle(fontWeight: FontWeight.w700)), trailing: Text('${p['stockQuantity']} / ${p['lowStockThreshold']}', style: TextStyle(fontWeight: FontWeight.w900, color: Brand.red)))]),
                      ),
                    if (alerts.isEmpty && lowStock.isEmpty) SizedBox(height: 300, child: EmptyView(title: context.tr('alerts.empty'), body: context.tr('alerts.emptyBody'), icon: Icons.notifications_none)),
                    for (final a in alerts)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Card(
                          color: a.isRead ? Brand.surface : Brand.purpleTint,
                          child: ListTile(
                            title: Text(_text(a), style: TextStyle(fontWeight: a.isRead ? FontWeight.w600 : FontWeight.w800)),
                            subtitle: Text(formatStamp(a.createdAt)),
                            onTap: () async {
                              if (!a.isRead) await _api.patch('/api/staff/alerts/${a.id}/read');
                              if (a.requestId != null && context.mounted) {
                                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: a.requestId!)));
                              }
                              _load();
                            },
                          ),
                        ),
                      ),
                  ]),
                ),
    );
  }
}

/// Technicians with their open jobs and availability.
class TechniciansScreen extends StatefulWidget {
  const TechniciansScreen({super.key});
  @override
  State<TechniciansScreen> createState() => _TechniciansScreenState();
}

class _TechniciansScreenState extends State<TechniciansScreen> {
  List<TechnicianInfo> items = [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<StaffSession>().api.get('/api/staff/technicians');
      if (mounted) setState(() => items = asList(asMap(r)['technicians']).map(TechnicianInfo.new).toList());
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('kanban.technicians'))),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: [SizedBox(height: 300, child: EmptyView(title: context.tr('kanban.noTechnicians')))])
                      : ListView(padding: const EdgeInsets.all(12), children: [
                          for (final t in items)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(backgroundColor: t.isAvailable ? Brand.greenTint : Brand.surfaceAlt, child: Icon(t.isAvailable ? Icons.check : Icons.pause, color: t.isAvailable ? Brand.green : Brand.muted)),
                                title: Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Text('${t.technicianType == null ? '' : '${context.tr('techType.${t.technicianType}')} · '}${t.isAvailable ? context.tr('common.free') : context.tr('shell.busy')} · ${context.tr('kanban.openJobs', params: {'count': t.openJobCount})}'),
                                trailing: IconButton(icon: Icon(Icons.call_outlined, color: Brand.purple), onPressed: () => openUri(context, telUri(t.phone))),
                              ),
                            ),
                        ]),
                ),
    );
  }
}

/// Orders for spare parts that are missing from stock; receiving one resumes the jobs that wait for it.
class PartOrdersScreen extends StatefulWidget {
  const PartOrdersScreen({super.key});
  @override
  State<PartOrdersScreen> createState() => _PartOrdersScreenState();
}

class _PartOrdersScreenState extends State<PartOrdersScreen> {
  String filter = 'open';
  List<PartOrderRow> orders = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = orders.isEmpty);
    try {
      final r = await _api.get('/api/staff/part-orders', query: {'status': filter == 'all' ? '' : filter});
      if (mounted) {
        setState(() {
          orders = asList(asMap(r)['orders']).map(PartOrderRow.new).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _set(PartOrderRow order, String status) async {
    try {
      await _api.patch('/api/staff/part-orders/${order.id}', body: {'status': status});
      _load();
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('parts.ordersTitle'))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: SegmentedChoice<String>(value: filter, options: {for (final f in ['open', 'received', 'all']) f: context.tr('parts.filter.$f')}, onChanged: (v) {
          setState(() => filter = v);
          _load();
        })),
        Expanded(
          child: loading
              ? const LoadingView()
              : error != null
                  ? ErrorView(error: error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: orders.isEmpty
                          ? ListView(children: [SizedBox(height: 260, child: EmptyView(title: context.tr('parts.noOrdersTitle'), body: context.tr('parts.noOrdersBody')))])
                          : ListView(padding: const EdgeInsets.fromLTRB(12, 0, 12, 24), children: [
                              for (final o in orders)
                                Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Row(children: [Expanded(child: Text('${o.part.localized(locale)} × ${o.quantity}', style: const TextStyle(fontWeight: FontWeight.w900))), Pill(context.tr('parts.status.${o.status}'))]),
                                      if (o.requestDisplayId != null) Text('${context.tr('parts.forRequest')}: ${formatRequestId(o.requestDisplayId!)}', style: TextStyle(color: Brand.muted, fontSize: 13)),
                                      if (o.status == 'requested' || o.status == 'ordered')
                                        Padding(
                                          padding: const EdgeInsets.only(top: 10),
                                          child: Row(children: [
                                            if (o.status == 'requested') Expanded(child: OutlinedButton(onPressed: () => _set(o, 'ordered'), child: Text(context.tr('parts.markOrdered')))),
                                            if (o.status == 'requested') const SizedBox(width: 8),
                                            Expanded(child: FilledButton(onPressed: () => _set(o, 'received'), child: Text(context.tr('parts.markReceived')))),
                                          ]),
                                        ),
                                    ]),
                                  ),
                                ),
                            ]),
                    ),
        ),
      ]),
    );
  }
}

/// Customers: search and call.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  List<Json> all = [];
  Object? error;
  bool loading = true;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<StaffSession>().api.get('/api/staff/customers');
      if (mounted) setState(() => all = asList(asMap(r)['customers']));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final digits = q.replaceAll(RegExp(r'\D'), '');
    final shown = all.where((c) => q.isEmpty || asString(c['name']).toLowerCase().contains(q) || (digits.length >= 3 && asString(c['phone']).contains(digits))).take(100).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.customers'))),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(controller: _q, onChanged: (_) => setState(() {}), decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('search.placeholder')))),
        Expanded(
          child: loading
              ? const LoadingView()
              : error != null
                  ? ErrorView(error: error!, onRetry: _load)
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = shown[i];
                        return ListTile(
                          title: Text(asString(c['name']), style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text('${formatPhone(asString(c['phone']))} · ${c['requestsCount'] ?? 0}'),
                          trailing: IconButton(icon: Icon(Icons.call_outlined, color: Brand.purple), onPressed: () => openUri(context, telUri(asString(c['phone'])))),
                        );
                      },
                    ),
        ),
      ]),
    );
  }
}

/// Upcoming scheduled visits.
class VisitsScreen extends StatefulWidget {
  const VisitsScreen({super.key});
  @override
  State<VisitsScreen> createState() => _VisitsScreenState();
}

class _VisitsScreenState extends State<VisitsScreen> {
  List<Job> jobs = [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final from = DateTime.now();
    final to = from.add(const Duration(days: 14));
    try {
      final r = await context.read<StaffSession>().api.get('/api/staff/requests', query: {'from': isoDate(from), 'to': isoDate(to)});
      if (mounted) setState(() => jobs = asList(asMap(r)['requests']).map(Job.new).where((j) => j.scheduledAt != null && !isTerminalStatus(j.status)).toList());
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final byDay = <String, List<Job>>{};
    for (final j in jobs) {
      byDay.putIfAbsent(isoDate(j.scheduledAt!.toLocal()), () => []).add(j);
    }
    final days = byDay.keys.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('calendar.title'))),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: days.isEmpty
                      ? ListView(children: [SizedBox(height: 300, child: EmptyView(title: context.tr('calendar.free'), icon: Icons.event_available_outlined))])
                      : ListView(padding: const EdgeInsets.all(12), children: [
                          for (final day in days) ...[
                            Padding(padding: const EdgeInsets.fromLTRB(4, 12, 4, 6), child: Text(formatDate(day), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                            for (final j in byDay[day]!..sort((a, b) => a.scheduledAt!.compareTo(b.scheduledAt!)))
                              Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: ListTile(
                                  leading: Text(formatTime(j.scheduledAt!), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                                  title: Text(j.customer.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                                  subtitle: Text('${formatRequestId(j.displayId)} · ${j.assignedTechnicianName ?? context.tr('common.unassigned')}'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: j.id))),
                                ),
                              ),
                          ],
                        ]),
                ),
    );
  }
}
