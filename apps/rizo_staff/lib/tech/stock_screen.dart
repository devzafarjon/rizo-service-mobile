import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// The parts the technician carries. On a job they are used before the warehouse stock.
class StockScreen extends StatefulWidget {
  const StockScreen({super.key});
  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  List<Json> rows = [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<StaffSession>().api.get('/api/staff/my-jobs/stock');
      if (mounted) setState(() => rows = asList(asMap(r)['stock']));
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('techStock.mineTitle'))),
      body: loading
          ? const LoadingView()
          : error != null && rows.isEmpty
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: rows.isEmpty
                      ? ListView(children: [SizedBox(height: 320, child: EmptyView(title: context.tr('techStock.mineEmpty'), body: context.tr('techStock.mineEmptyBody')))])
                      : ListView(padding: const EdgeInsets.all(14), children: [
                          Text(context.tr('techStock.mineIntro'), style: TextStyle(color: Brand.muted)),
                          const SizedBox(height: 12),
                          for (final row in rows)
                            Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                title: Text(Named.fromJson(row).localized(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
                                trailing: Pill('${row['quantity']}', color: Brand.purple, background: Brand.purpleTint),
                              ),
                            ),
                        ]),
                ),
    );
  }
}
