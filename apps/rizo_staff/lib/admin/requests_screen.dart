import 'dart:async';

import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'new_request_screen.dart';
import 'request_detail_screen.dart';

/// All requests for the office: search, filter by stage and type, pull to refresh.
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});
  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  static const _filters = ['open', 'new', 'working', 'waiting', 'ready', 'done', 'overdue', 'unassigned', 'all'];
  List<Job> jobs = [];
  Object? error;
  bool loading = true;
  String filter = 'open';
  String type = '';
  final _search = TextEditingController();
  Timer? _debounce;
  Timer? _poll;

  StaffSession get _session => context.read<StaffSession>();

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 40), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => loading = jobs.isEmpty);
    try {
      final result = await _session.api.get('/api/staff/requests', query: {'q': _search.text.trim(), 'type': type});
      if (mounted) {
        setState(() {
          jobs = asList(asMap(result)['requests']).map(Job.new).toList();
          error = null;
        });
      }
    } catch (e) {
      if (mounted && !silent) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool _match(Job j) => switch (filter) {
        'open' => !isTerminalStatus(j.status),
        'new' => j.status == 'new',
        'working' => j.status == 'diagnosing' || j.status == 'in_progress',
        'waiting' => const ['awaiting_decision', 'awaiting_parts', 'paused'].contains(j.status),
        'ready' => j.status == 'ready',
        'done' => isTerminalStatus(j.status),
        'overdue' => j.isOverdue && !isTerminalStatus(j.status),
        'unassigned' => j.assignedTechnicianId == null && !isTerminalStatus(j.status),
        _ => true,
      };

  @override
  Widget build(BuildContext context) {
    final shown = jobs.where(_match).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.requests')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Brand.purple,
        foregroundColor: Colors.white,
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const NewRequestScreen()));
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('nav.newRequest')),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: TextField(
            controller: _search,
            onChanged: (_) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 350), _load);
            },
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: context.tr('kanban.searchPlaceholder'), suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _load(); })),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final f in _filters)
              Padding(
                padding: const EdgeInsets.only(right: 8, top: 6, bottom: 6),
                child: ChoiceChip(label: Text(context.tr('mobile.filter.$f')), selected: filter == f, onSelected: (_) => setState(() => filter = f)),
              ),
            const VerticalDivider(width: 12),
            for (final t in const ['repair', 'installation'])
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 6, bottom: 6),
                child: FilterChip(label: Text(context.tr('type.$t')), selected: type == t, onSelected: (v) { setState(() => type = v ? t : ''); _load(); }),
              ),
          ]),
        ),
        Expanded(
          child: loading
              ? const LoadingView()
              : error != null && jobs.isEmpty
                  ? ErrorView(error: error!, onRetry: _load)
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: shown.isEmpty
                          ? ListView(children: [SizedBox(height: 300, child: EmptyView(title: context.tr('requests.emptyTitle', def: context.tr('tech.noJobs'))))])
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 90),
                              itemCount: shown.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (_, i) => _RequestTile(job: shown[i], onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: shown[i].id)));
                                _load(silent: true);
                              }),
                            ),
                    ),
        ),
      ]),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.job, required this.onTap});
  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(formatRequestId(job.displayId), style: const TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w800, fontSize: 12)),
              const Spacer(),
              if (job.isOverdue && !isTerminalStatus(job.status)) const Icon(Icons.warning_amber_rounded, color: Brand.red, size: 18),
              if (job.isOnSite) const Padding(padding: EdgeInsets.only(left: 4), child: Icon(Icons.place, size: 18, color: Brand.orange)),
            ]),
            Text(job.customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            Text('${job.product.name(locale)}${job.serialNumber != null ? ' · ${job.serialNumber}' : ''}', style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              TypeChip(job.type),
              StatusChip(job.status),
              if (job.payment.balance > 0 && isDoneStatus(job.status)) Pill(context.tr('detail.owes', params: {'amount': formatMoney(job.payment.balance)}), color: Brand.red, background: Brand.redTint),
              Text(job.assignedTechnicianName ?? context.tr('common.unassigned'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: job.assignedTechnicianName == null ? Brand.orangeText : const Color(0xFF6B7280))),
            ]),
            if (job.timer != null) Padding(padding: const EdgeInsets.only(top: 8), child: CountdownChip(job.timer!, compact: true)),
          ]),
        ),
      ),
    );
  }
}
