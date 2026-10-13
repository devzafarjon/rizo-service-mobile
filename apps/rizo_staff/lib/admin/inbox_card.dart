import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../directory/directory_screen.dart';
import '../parts/parts_screen.dart';
import '../warehouse/warehouse_screen.dart';
import 'feedback_screen.dart';
import 'requests_screen.dart';

/// "My work": what waits for the admin right now (counted live on the server, so a row disappears when it is dealt with).
class InboxCard extends StatefulWidget {
  const InboxCard({super.key});
  @override
  State<InboxCard> createState() => InboxCardState();
}

class InboxCardState extends State<InboxCard> {
  List<Json> items = [];
  int total = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    reload();
  }

  /// Called by the dashboard on pull to refresh.
  Future<void> reload() async {
    try {
      final r = asMap(await context.read<StaffSession>().api.get('/api/staff/inbox'));
      if (mounted) {
        setState(() {
          items = asList(r['items']);
          total = asInt(r['total']);
          loaded = true;
        });
      }
    } catch (_) {
      // The card is a convenience: a failed refresh keeps what was shown (or nothing).
    }
  }

  void _open(String key) {
    final Widget page = switch (key) {
      'legal' => const RequestsScreen(initialFilter: 'legal'),
      'overdue' => const RequestsScreen(initialFilter: 'overdue'),
      'unassigned' => const RequestsScreen(initialFilter: 'unassigned'),
      'decision' => const RequestsScreen(initialFilter: 'decision'),
      'partsNoOrder' => const PartsControlScreen(initialTab: 1),
      'partsLate' => const PartsControlScreen(initialTab: 2),
      'partsToOrder' => const PartsControlScreen(initialTab: 0),
      'transfers' => const WarehouseScreen(),
      'catalogPending' => const DirectoryScreen(),
      'lowRatings' => const FeedbackScreen(),
      _ => const RequestsScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page)).then((_) => reload());
  }

  ({Color fg, Color bg}) _tone(String tone) => switch (tone) {
        'red' => (fg: Brand.red, bg: Brand.redTint),
        'orange' => (fg: Brand.orangeText, bg: Brand.orangeTint),
        _ => (fg: Brand.blue, bg: Brand.blueTint),
      };

  @override
  Widget build(BuildContext context) {
    if (!loaded) return const SizedBox.shrink();
    return Section(
      title: context.tr('inbox.title'),
      trailing: items.isEmpty ? Icon(Icons.check_circle, color: Brand.green) : Pill('$total', color: Colors.white, background: Brand.purple),
      child: items.isEmpty
          ? Text(context.tr('inbox.allClear'), style: TextStyle(color: Brand.muted))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(context.tr('inbox.subtitle', count: total), style: TextStyle(color: Brand.muted, fontSize: 13))),
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _open(asString(item['key'])),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(border: Border.all(color: Brand.border), borderRadius: BorderRadius.circular(12)),
                      child: Row(children: [
                        Container(
                          constraints: const BoxConstraints(minWidth: 36),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                          decoration: BoxDecoration(color: _tone(asString(item['tone'])).bg, borderRadius: BorderRadius.circular(10)),
                          child: Text('${item['count']}', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, color: _tone(asString(item['tone'])).fg)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.tr('inbox.rows.${item['key']}.title'), style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 2, overflow: TextOverflow.ellipsis),
                            Text(context.tr('inbox.rows.${item['key']}.hint'), style: TextStyle(color: Brand.muted, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          ]),
                        ),
                        Icon(Icons.chevron_right, color: Brand.faint),
                      ]),
                    ),
                  ),
                ),
            ]),
    );
  }
}
