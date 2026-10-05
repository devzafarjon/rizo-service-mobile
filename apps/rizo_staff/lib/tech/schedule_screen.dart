import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Which of the next two weeks the technician works (auto-assignment skips days off).
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});
  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  final Map<String, bool> working = {};
  Object? error;
  bool loading = true;
  late final List<DateTime> days = [for (var i = 0; i < 14; i++) DateTime.now().add(Duration(days: i))];

  StaffSession get _session => context.read<StaffSession>();

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
      final result = await _session.api.get('/api/staff/my-jobs/schedule', query: {'from': isoDate(days.first), 'to': isoDate(days.last)});
      working.clear();
      for (final row in asList(asMap(result)['days'])) {
        working[asString(row['date'])] = row['isWorking'] == true;
      }
    } catch (e) {
      error = e;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _set(DateTime day, bool value) async {
    final key = isoDate(day);
    final before = working[key];
    setState(() => working[key] = value);
    try {
      await _session.api.put('/api/staff/my-jobs/schedule', body: {'date': key, 'isWorking': value});
    } catch (e) {
      if (!mounted) return;
      setState(() => before == null ? working.remove(key) : working[key] = before);
      showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.mySchedule'))),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : ListView(padding: const EdgeInsets.all(16), children: [
                  for (final day in days)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: SwitchListTile(
                        // A day with nothing saved counts as a working day.
                        value: working[isoDate(day)] ?? true,
                        onChanged: (v) => _set(day, v),
                        title: Text(formatDate(isoDate(day)), style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text((working[isoDate(day)] ?? true) ? context.tr('schedule.on') : context.tr('schedule.off')),
                      ),
                    ),
                ]),
    );
  }
}
