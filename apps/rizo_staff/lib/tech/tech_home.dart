import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../common/settings_screen.dart';
import 'actions.dart';
import 'earnings_screen.dart';
import 'job_card.dart';
import 'job_screen.dart';
import 'scan_screen.dart';
import 'schedule_screen.dart';
import 'sync_bar.dart';

/// The technician's board (tablet: four columns side by side; phone: one column per tab).
class TechHome extends StatefulWidget {
  const TechHome({super.key});
  @override
  State<TechHome> createState() => _TechHomeState();
}

class _TechHomeState extends State<TechHome> with WidgetsBindingObserver {
  late final TechRepository repo;
  int _shownFailures = 0;

  @override
  void initState() {
    super.initState();
    repo = TechRepository(context.read<StaffSession>());
    repo.addListener(_onRepoChange);
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    repo.startAutoSync();
  }

  Future<void> _refresh() async {
    try {
      await repo.refresh();
    } catch (error) {
      if (mounted) showSnack(context, context.errorText(error), error: true);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) repo.refresh(silent: true);
  }

  void _onRepoChange() {
    if (!mounted || repo.failures.length == _shownFailures) return;
    _shownFailures = repo.failures.length;
    if (repo.failures.isEmpty) return;
    final items = [...repo.failures];
    repo.clearFailures();
    _shownFailures = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.tr('mobile.syncFailedTitle')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(ctx.tr('mobile.syncFailedBody'), style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 10),
              for (final f in items) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('${formatRequestId(f.displayId)} · ${f.message}', style: const TextStyle(fontWeight: FontWeight.w700))),
            ]),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('common.close')))],
        ),
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    repo.removeListener(_onRepoChange);
    repo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TechRepository>.value(value: repo, child: const _Board());
  }
}

class _Board extends StatelessWidget {
  const _Board();

  void _openJob(BuildContext context, String id) {
    final repo = context.read<TechRepository>();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ChangeNotifierProvider<TechRepository>.value(value: repo, child: JobScreen(jobId: id))));
  }

  Widget _scan(BuildContext context) {
    final repo = context.read<TechRepository>();
    return ScanScreen(resolve: (displayId) async {
      final work = await repo.lookup(displayId);
      return ChangeNotifierProvider<TechRepository>.value(value: repo, child: JobScreen(jobId: work.job.id));
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TechRepository>();
    final actions = TechActions(context, repo);
    final wide = isWide(context) && isTablet(context);
    final byColumn = {for (final c in techColumns) c: <Job>[]};
    for (final job in repo.jobs) {
      byColumn[job.column ?? techColumnOf(job.status)]?.add(job);
    }

    Widget list(String column) {
      final jobs = byColumn[column]!;
      return RefreshIndicator(
        onRefresh: () => repo.refresh(),
        child: jobs.isEmpty
            ? ListView(children: [Padding(padding: const EdgeInsets.all(40), child: Center(child: Text(context.tr('tech.noJobs'), style: const TextStyle(color: Color(0xFF9CA3AF)))))])
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: jobs.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => JobCard(job: jobs[i], actions: actions, pending: repo.hasPending(jobs[i].id), onOpen: () => _openJob(context, jobs[i].id)),
              ),
      );
    }

    final menu = PopupMenuButton<String>(
      onSelected: (value) {
        final route = switch (value) {
          'scan' => _scan(context),
          'schedule' => const ScheduleScreen(),
          'earnings' => const EarningsScreen(),
          _ => SettingsScreen(repository: repo),
        };
        Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => route));
      },
      itemBuilder: (ctx) => [
        PopupMenuItem(value: 'schedule', child: ListTile(leading: const Icon(Icons.calendar_month_outlined), title: Text(ctx.tr('nav.mySchedule')), contentPadding: EdgeInsets.zero)),
        PopupMenuItem(value: 'earnings', child: ListTile(leading: const Icon(Icons.account_balance_wallet_outlined), title: Text(ctx.tr('nav.myEarnings')), contentPadding: EdgeInsets.zero)),
        PopupMenuItem(value: 'settings', child: ListTile(leading: const Icon(Icons.settings_outlined), title: Text(ctx.tr('mobile.settings')), contentPadding: EdgeInsets.zero)),
      ],
    );

    final title = Text(context.tr('tech.title'));
    final actionsBar = [
      IconButton(tooltip: context.tr('nav.scan'), onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _scan(context))), icon: const Icon(Icons.qr_code_scanner)),
      IconButton(onPressed: repo.loading ? null : () => repo.refresh(), icon: repo.loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh)),
      menu,
    ];

    if (wide) {
      return Scaffold(
        appBar: AppBar(title: title, actions: actionsBar),
        body: Column(children: [
          const SyncBar(),
          Expanded(
            child: LayoutBuilder(builder: (context, constraints) {
              // Four columns share the screen on a wide tablet; on a narrower one they scroll sideways.
              final fit = constraints.maxWidth >= 1000;
              final columns = [
                for (final c in techColumns)
                  Container(
                    width: fit ? null : 310,
                    margin: const EdgeInsets.fromLTRB(8, 8, 0, 8),
                    decoration: BoxDecoration(color: const Color(0xFFE5E7EB).withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
                    child: Column(children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        child: Row(children: [
                          Expanded(child: Text(context.tr('techColumn.$c'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15))),
                          Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99)), child: Text('${byColumn[c]!.length}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        ]),
                      ),
                      Expanded(child: list(c)),
                    ]),
                  ),
              ];
              if (fit) {
                return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [for (final column in columns) Expanded(child: column), const SizedBox(width: 8)]);
              }
              return ListView(scrollDirection: Axis.horizontal, children: [...columns, const SizedBox(width: 8)]);
            }),
          ),
        ]),
      );
    }

    return DefaultTabController(
      length: techColumns.length,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          actions: actionsBar,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Brand.purple,
            indicatorColor: Brand.purple,
            tabs: [for (final c in techColumns) Tab(text: '${context.tr('techColumn.$c')} (${byColumn[c]!.length})')],
          ),
        ),
        body: Column(children: [
          const SyncBar(),
          Expanded(child: TabBarView(children: [for (final c in techColumns) list(c)])),
        ]),
      ),
    );
  }
}
