import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// The repair estimate the customer approves or declines. Optional lines are the customer's choice.
class CustomerEstimateCard extends StatefulWidget {
  const CustomerEstimateCard({super.key, required this.estimate, required this.onApprove, required this.onDecline});
  final PortalEstimate estimate;
  final Future<void> Function(List<String> optionalLineIds) onApprove;
  final Future<void> Function(String reason) onDecline;

  @override
  State<CustomerEstimateCard> createState() => _CustomerEstimateCardState();
}

class _CustomerEstimateCardState extends State<CustomerEstimateCard> {
  late List<String> chosen = [for (final l in widget.estimate.lines) if (l.isOptional && l.isSelected) l.id];
  bool declining = false;
  final _reason = TextEditingController();

  double get _total => widget.estimate.lines.where((l) => !l.isOptional || chosen.contains(l.id)).fold(0, (s, l) => s + l.quantity * l.unitPrice);

  @override
  Widget build(BuildContext context) {
    final e = widget.estimate;
    final locale = context.watch<Translator>().locale;
    final approved = e.status == 'approved';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Brand.orangeTint, borderRadius: BorderRadius.circular(18), border: Border.all(color: Brand.orange.withValues(alpha: 0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(context.tr('portal.estimateTitle').toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13))),
          Pill(context.tr('estimate.status.${e.status}'), color: approved ? Brand.green : (e.status == 'declined' || e.status == 'expired' ? Brand.red : Brand.purple), background: Colors.white),
        ]),
        if (e.canRespond && e.validUntil != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('portal.estimateAsk', params: {'date': formatStamp(e.validUntil)}), style: const TextStyle(color: Color(0xFF8A4B00), fontWeight: FontWeight.w800))),
        if (e.note != null && e.note!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(e.note!)),
        const SizedBox(height: 10),
        for (final line in e.lines)
          Builder(builder: (context) {
            final on = !line.isOptional || chosen.contains(line.id) || (approved && line.isSelected);
            final selectable = line.isOptional && e.canRespond;
            return InkWell(
              onTap: selectable ? () => setState(() => chosen.contains(line.id) ? chosen.remove(line.id) : chosen.add(line.id)) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  if (selectable) Padding(padding: const EdgeInsets.only(right: 8), child: Icon(chosen.contains(line.id) ? Icons.check_box : Icons.check_box_outline_blank, color: Brand.purple)),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(text: line.label(locale)),
                      if (line.quantity > 1) TextSpan(text: ' × ${line.quantity}', style: const TextStyle(color: Color(0xFF6B7280))),
                      if (line.isOptional) TextSpan(text: '  ${context.tr('estimate.optional')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                    ]), style: TextStyle(fontWeight: FontWeight.w600, decoration: approved && !line.isSelected ? TextDecoration.lineThrough : null, color: on ? Brand.ink : const Color(0xFF9CA3AF))),
                  ),
                  Text(formatMoney(line.quantity * line.unitPrice), style: TextStyle(fontWeight: FontWeight.w800, color: on ? Brand.ink : const Color(0xFF9CA3AF))),
                ]),
              ),
            );
          }),
        const Divider(),
        Row(children: [Text(context.tr('estimate.total'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), const Spacer(), Text(formatMoney(e.canRespond ? _total : e.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))]),
        if (e.canRespond) ...[
          const SizedBox(height: 14),
          if (declining) ...[
            TextField(controller: _reason, decoration: InputDecoration(hintText: context.tr('portal.declineReason'))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => declining = false), child: Text(context.tr('common.cancel')))),
              const SizedBox(width: 8),
              Expanded(child: BusyButton(label: context.tr('portal.decline'), danger: true, onPressed: () => widget.onDecline(_reason.text.trim()))),
            ]),
          ] else
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => setState(() => declining = true), child: Text(context.tr('portal.decline')))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: BusyButton(label: context.tr('portal.approve', params: {'amount': formatMoney(_total)}), icon: Icons.check, onPressed: () => widget.onApprove(chosen))),
            ]),
          const SizedBox(height: 8),
          Text(context.tr('portal.estimateFine'), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ],
      ]),
    );
  }
}
