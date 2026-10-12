import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Tells a customer whose job waits for a spare part whether it is ordered and when it should arrive.
class PartWaitBanner extends StatelessWidget {
  const PartWaitBanner({super.key, required this.wait});
  final PartWait? wait;

  @override
  Widget build(BuildContext context) {
    final w = wait;
    if (w == null) return const SizedBox.shrink();
    final color = w.late ? Brand.red : Brand.purple;
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: w.late ? Brand.red.withValues(alpha: 0.1) : Brand.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(Icons.inventory_2_outlined, size: 18, color: color), const SizedBox(width: 8), Expanded(child: Text(context.tr('portal.partWait.title'), style: TextStyle(fontWeight: FontWeight.w900, color: color)))]),
        const SizedBox(height: 6),
        Text(w.ordered ? context.tr('portal.partWait.ordered') : context.tr('portal.partWait.notOrdered'), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        if (w.expectedAt != null) Text(context.tr('portal.partWait.expected', params: {'date': formatDate(w.expectedAt!)}), style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        if (w.late) Padding(padding: const EdgeInsets.only(top: 2), child: Text(context.tr('portal.partWait.late'), style: TextStyle(fontWeight: FontWeight.w800, color: color))),
      ]),
    );
  }
}
