import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../i18n.dart';
import '../models.dart';
import '../theme.dart';

/// A day and one of its free booking windows.
class VisitChoice {
  const VisitChoice(this.date, this.slot);
  final String date; // YYYY-MM-DD
  final String slot; // 10:00-12:00
}

String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Lets the user pick a date and then a free window. [loadSlots] asks the API for the windows of a day.
/// Returns null when closed without choosing.
Future<VisitChoice?> pickVisitSlot(BuildContext context, {required Future<List<VisitSlot>> Function(String date) loadSlots, String? initialDate}) {
  return showModalBottomSheet<VisitChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _VisitSheet(loadSlots: loadSlots, initialDate: initialDate),
  );
}

class _VisitSheet extends StatefulWidget {
  const _VisitSheet({required this.loadSlots, this.initialDate});
  final Future<List<VisitSlot>> Function(String date) loadSlots;
  final String? initialDate;
  @override
  State<_VisitSheet> createState() => _VisitSheetState();
}

class _VisitSheetState extends State<_VisitSheet> {
  String? date;
  List<VisitSlot> slots = [];
  String? slot;
  bool loading = false;
  Object? error;

  @override
  void initState() {
    super.initState();
    date = widget.initialDate;
    if (date != null) _load();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: date != null ? (DateTime.tryParse(date!) ?? now) : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (picked == null) return;
    setState(() {
      date = _ymd(picked);
      slot = null;
    });
    await _load();
  }

  Future<void> _load() async {
    final day = date;
    if (day == null) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.loadSlots(day);
      if (mounted && date == day) setState(() => slots = result);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final anyFree = slots.any((s) => s.free);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('visit.book'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.event),
            label: Text(date == null ? context.tr('visit.date') : date!),
          ),
          const SizedBox(height: 14),
          if (date == null)
            Text(context.tr('visit.pickDate'), style: TextStyle(color: Brand.muted))
          else if (loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Center(child: CircularProgressIndicator()))
          else if (error != null)
            Text(context.errorText(error!), style: TextStyle(color: Brand.red))
          else if (!anyFree)
            Text(context.tr('visit.noSlots'), style: TextStyle(color: Brand.muted))
          else
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final s in slots)
                ChoiceChip(
                  label: Text(s.slot.replaceFirst('-', ' – ')),
                  selected: slot == s.slot,
                  onSelected: s.free ? (_) => setState(() => slot = s.slot) : null,
                ),
            ]),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: date != null && slot != null ? () => Navigator.of(context).pop(VisitChoice(date!, slot!)) : null,
            child: Text(context.tr('common.save')),
          ),
        ]),
      ),
    );
  }
}
