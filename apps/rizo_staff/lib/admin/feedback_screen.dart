import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'request_detail_screen.dart';

/// What customers wrote about finished jobs: average, rating spread, and every rating with its comment and tags.
/// The same data as the website's "Customer feedback" report (admin only).
class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  static const _bands = {'all': <String, String>{}, 'low': {'maxRating': '2'}, 'mid': {'minRating': '3', 'maxRating': '3'}, 'high': {'minRating': '4'}};
  String preset = 'month';
  String band = 'all';
  bool onlyComments = false;
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
      loading = data == null;
      error = null;
    });
    try {
      final r = await context.read<StaffSession>().api.get('/api/staff/reports/feedback', query: {
        'preset': preset,
        ..._bands[band]!,
        if (onlyComments) 'withComment': '1',
      });
      if (mounted) setState(() => data = asMap(r));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data;
    final summary = d == null ? <String, dynamic>{} : asMap(d['summary']);
    final items = d == null ? <Json>[] : asList(d['items']);
    final average = summary['average'];
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('reports.nav.feedback')), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.all(12), children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final p in ['week', 'month', 'quarter', 'year', 'all'])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(context.tr('reports.preset.$p')),
                    selected: preset == p,
                    onSelected: (_) {
                      setState(() => preset = p);
                      _load();
                    },
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final b in _bands.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(context.tr('reports.feedback.band.$b')),
                    selected: band == b,
                    onSelected: (_) {
                      setState(() => band = b);
                      _load();
                    },
                  ),
                ),
              FilterChip(
                label: Text(context.tr('reports.feedback.onlyComments')),
                selected: onlyComments,
                onSelected: (v) {
                  setState(() => onlyComments = v);
                  _load();
                },
              ),
            ]),
          ),
          const SizedBox(height: 12),
          if (loading) const LoadingView(),
          if (error != null && d == null) ErrorView(error: error!, onRetry: _load),
          if (d != null) ...[
            Row(children: [
              _Stat(label: context.tr('reports.feedback.average'), value: average == null ? '—' : '${asDouble(average).toStringAsFixed(1)} / 5', color: Brand.orange),
              const SizedBox(width: 8),
              _Stat(label: context.tr('reports.feedback.count'), value: '${asInt(summary['count'])}', color: Brand.purple),
              const SizedBox(width: 8),
              _Stat(label: context.tr('reports.feedback.withComment'), value: '${asInt(summary['withComment'])}', color: Brand.green),
            ]),
            const SizedBox(height: 12),
            _Distribution(rows: asList(summary['distribution'])),
            const SizedBox(height: 12),
            if (items.isEmpty)
              SizedBox(height: 200, child: EmptyView(title: context.tr('reports.feedback.emptyTitle')))
            else
              for (final row in items) _FeedbackCard(row: row),
            if (d['truncated'] == true) Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.tr('reports.feedback.truncated'), style: TextStyle(color: Brand.muted, fontSize: 12))),
          ],
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(14), border: Border(left: BorderSide(color: color, width: 4))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label.toUpperCase(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: Brand.muted, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(color: Brand.purple, fontSize: 18, fontWeight: FontWeight.w900)),
        ]),
      ),
    );
  }
}

class _Distribution extends StatelessWidget {
  const _Distribution({required this.rows});
  final List<Json> rows;

  @override
  Widget build(BuildContext context) {
    final maxCount = rows.fold<int>(1, (m, r) => asInt(r['count']) > m ? asInt(r['count']) : m);
    return Section(
      title: context.tr('reports.feedback.distribution'),
      child: Column(children: [
        for (final r in rows.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 34, child: Text('${asInt(r['rating'])} ★', style: const TextStyle(fontWeight: FontWeight.w800))),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(value: asInt(r['count']) / maxCount, minHeight: 10, backgroundColor: Brand.surfaceAlt, color: Brand.orange),
                ),
              ),
              SizedBox(width: 34, child: Text('${asInt(r['count'])}', textAlign: TextAlign.right, style: TextStyle(color: Brand.muted))),
            ]),
          ),
      ]),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.row});
  final Json row;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final rating = asInt(row['rating']);
    final request = asMap(row['request']);
    final comment = asString(row['comment']);
    final tags = (row['tags'] is List) ? (row['tags'] as List).map((e) => e.toString()).toList() : <String>[];
    final technician = row['technician'] is Map ? asString(asMap(row['technician'])['name']) : context.tr('common.unassigned');
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: rating <= 2 ? Brand.red.withValues(alpha: 0.35) : Brand.line)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: asString(request['id'])))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (var v = 1; v <= 5; v++) Icon(v <= rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 20, color: v <= rating ? Brand.orange : Brand.line),
              const SizedBox(width: 6),
              Text('$rating / 5', style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(formatDateTime(DateTime.tryParse(asString(row['createdAt']))?.toLocal()), style: TextStyle(color: Brand.faint, fontSize: 12)),
            ]),
            const SizedBox(height: 8),
            Text(comment.isEmpty ? context.tr('reports.feedback.noComment') : comment, style: TextStyle(fontSize: 14, color: comment.isEmpty ? Brand.faint : Brand.ink)),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 4, children: [for (final tag in tags) Pill(context.tr('feedback.tag.$tag'), color: Brand.purple, background: Brand.purpleTint)]),
            ],
            const Divider(height: 18),
            Text(
              '${formatRequestId(asString(request['displayId']))} · ${asString(asMap(row['customer'])['name'])} · ${Named.fromJson(request['product']).localized(locale)} · $technician',
              style: TextStyle(color: Brand.muted, fontSize: 12),
            ),
          ]),
        ),
      ),
    );
  }
}
