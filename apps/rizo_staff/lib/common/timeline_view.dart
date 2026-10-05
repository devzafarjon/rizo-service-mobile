import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// The history of a request: who did what and when (translated from the server's keys).
class TimelineView extends StatelessWidget {
  const TimelineView(this.events, {super.key});
  final List<TimelineEvent> events;

  Color _dot(String kind) => switch (kind) {
        'arrived' || 'paused' || 'en_route' || 'decision' => Brand.orange,
        'completed' => const Color(0xFF10B981),
        'picked_up' => Brand.green,
        _ => Brand.purple,
      };

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    if (events.isEmpty) return Text(tr('timeline.empty'), style: const TextStyle(color: Color(0xFF6B7280)));
    return Column(children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 16,
              child: Column(children: [
                Container(margin: const EdgeInsets.only(top: 5), width: 12, height: 12, decoration: BoxDecoration(color: _dot(events[i].kind), shape: BoxShape.circle)),
                if (i < events.length - 1) Expanded(child: Container(width: 1, color: Brand.border)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(child: Padding(padding: EdgeInsets.only(bottom: i < events.length - 1 ? 16 : 0), child: _entry(events[i]))),
          ]),
        ),
    ]);
  }

  Widget _entry(TimelineEvent e) {
    final planned = e.params['hours'] != null ? formatDurationHours(asDouble(e.params['hours'])) : '';
    final lasted = e.params['durationMs'] != null ? formatDurationMs(asInt(e.params['durationMs'])) : '';
    final title = tr(e.titleKey ?? 'timeline.${e.kind}', def: e.title);
    final detail = e.detailKey != null ? tr(e.detailKey!, params: {'reason': e.params['reason'], 'planned': planned, 'lasted': lasted}, def: e.detail) : e.detail;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
      Text(formatStamp(e.at), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6B7280))),
      if (detail != null && detail.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 2), child: Text(detail, style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563)))),
    ]);
  }
}
