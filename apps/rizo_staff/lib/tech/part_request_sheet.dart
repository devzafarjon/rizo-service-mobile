import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import '../warehouse/source_picker.dart';

/// What the technician decided: the part, how many, and where it should come from (null = the fastest way, picked by the server).
typedef PartRequest = ({int quantity, String? note, Map<String, Object?>? source});

/// A part the job needs but the shelf lacks: see which warehouses have it and how soon, pick one (the fastest is preselected).
/// Needs the network; without it the technician can still send the request and the fastest source is chosen when it syncs.
Future<PartRequest?> showPartRequestSheet(BuildContext context, {required String jobId, required CatalogChoice part}) {
  return showModalBottomSheet<PartRequest>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _PartRequestSheet(jobId: jobId, part: part));
}

class _PartRequestSheet extends StatefulWidget {
  const _PartRequestSheet({required this.jobId, required this.part});
  final String jobId;
  final CatalogChoice part;
  @override
  State<_PartRequestSheet> createState() => _PartRequestSheetState();
}

class _PartRequestSheetState extends State<_PartRequestSheet> {
  final _qty = TextEditingController(text: '1');
  final _note = TextEditingController();
  List<SourceOption> options = [];
  String choice = '';
  String? destination;
  int atDestination = 0;
  bool loading = true;
  bool offline = false;

  int get _count => (int.tryParse(_qty.text.trim()) ?? 1).clamp(1, 99);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      offline = false;
    });
    try {
      final r = asMap(await context.read<StaffSession>().api.get('/api/staff/my-jobs/part-sources', query: {'partId': widget.part.id, 'quantity': '$_count', 'jobId': widget.jobId}));
      final list = asList(r['options']).map((e) => SourceOption(asMap(e))).toList();
      if (!mounted) return;
      setState(() {
        options = list;
        destination = asMap(r['destination'])['name']?.toString();
        atDestination = asInt(r['atDestination']);
        choice = list.where((o) => o.recommended).map((o) => o.key).firstOrNull ?? '';
      });
    } catch (_) {
      if (mounted) setState(() => offline = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _send() {
    final note = _note.text.trim();
    Map<String, Object?>? source;
    if (!offline && choice.isNotEmpty) {
      source = choice == 'supplier' ? {'type': 'supplier'} : {'type': 'warehouse', 'warehouseId': choice.replaceFirst('wh:', '')};
    }
    Navigator.of(context).pop((quantity: _count, note: note.isEmpty ? null : note, source: source));
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('warehouse.partRequestTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(widget.part.names.localized(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 14),
            Labeled(context.tr('common.qty'), child: TextField(controller: _qty, keyboardType: TextInputType.number, onSubmitted: (_) => _load())),
            if (loading)
              const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
            else if (offline)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Brand.orangeTint, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(Icons.cloud_off_outlined, color: Brand.orangeText, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(context.tr('warehouse.offlineFastest'), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w700, fontSize: 13))),
                  TextButton(onPressed: _load, child: Text(context.tr('mobile.retry'))),
                ]),
              )
            else ...[
              if (destination != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${context.tr('warehouse.deliverTo', params: {'name': destination})} · ${context.tr('warehouse.thereNow', params: {'count': atDestination})}', style: TextStyle(color: Brand.muted, fontSize: 12.5)),
                ),
              Text(context.tr('warehouse.source.title').toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.subtle)),
              const SizedBox(height: 8),
              SourcePicker(options: options, value: choice, onChanged: (o) => setState(() => choice = o.key)),
            ],
            Labeled(context.tr('payments.note'), child: TextField(controller: _note, maxLength: 200)),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: loading || (!offline && choice.isEmpty) ? null : _send, child: Text(context.tr('warehouse.ask')))),
          ]),
        ),
      ),
    );
  }
}
