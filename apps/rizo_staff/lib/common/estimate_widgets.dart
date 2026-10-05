import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

class _Draft {
  _Draft({required this.kind, required this.name, required this.unitPrice, this.serviceId, this.partId});
  final String kind;
  final String name;
  final String? serviceId;
  final String? partId;
  int quantity = 1;
  double unitPrice;
  bool optional = false;

  Json toJson() => {
        'kind': kind,
        if (serviceId != null) 'serviceCatalogItemId': serviceId,
        if (partId != null) 'sparePartId': partId,
        'name': name,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'isOptional': optional,
      };
}

/// Builds a price estimate: catalog services and parts plus free-text labour. Optional lines are the customer's choice.
class EstimateBuilder extends StatefulWidget {
  const EstimateBuilder({super.key, required this.services, required this.parts, required this.onSubmit, this.allowDraft = true});
  final List<CatalogChoice> services;
  final List<CatalogChoice> parts;
  final bool allowDraft;
  final Future<void> Function(List<Json> lines, String note, bool send) onSubmit;

  @override
  State<EstimateBuilder> createState() => _EstimateBuilderState();
}

class _EstimateBuilderState extends State<EstimateBuilder> {
  final List<_Draft> _lines = [];
  final _note = TextEditingController();
  final _customName = TextEditingController();
  final _customPrice = TextEditingController();

  double get _total => _lines.where((l) => !l.optional).fold(0, (s, l) => s + l.quantity * l.unitPrice);
  double get _optionalTotal => _lines.where((l) => l.optional).fold(0, (s, l) => s + l.quantity * l.unitPrice);

  Future<void> _pick(List<CatalogChoice> items, String kind) async {
    final locale = Translator.I.locale;
    final chosen = await showModalBottomSheet<CatalogChoice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (_, controller) => ListView(controller: controller, children: [
          for (final item in items)
            ListTile(
              title: Text(item.names.localized(locale), style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: item.stockQuantity != null ? Text(ctx.tr('common.inStock', params: {'count': item.stockQuantity})) : null,
              trailing: Text(formatMoney(item.price), style: const TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(ctx, item),
            ),
        ]),
      ),
    );
    if (chosen == null) return;
    setState(() => _lines.add(_Draft(kind: kind, name: chosen.names.localized(locale), unitPrice: chosen.price, serviceId: kind == 'service' ? chosen.id : null, partId: kind == 'part' ? chosen.id : null)));
  }

  Future<void> _submit(bool send) async {
    if (_lines.isEmpty) return;
    await widget.onSubmit(_lines.map((l) => l.toJson()).toList(), _note.text.trim(), send);
    if (mounted) {
      setState(() => _lines.clear());
      _note.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        Expanded(child: OutlinedButton.icon(onPressed: widget.services.isEmpty ? null : () => _pick(widget.services, 'service'), icon: const Icon(Icons.build_outlined, size: 18), label: Text(context.tr('estimate.addService'), overflow: TextOverflow.ellipsis))),
        const SizedBox(width: 8),
        Expanded(child: OutlinedButton.icon(onPressed: widget.parts.isEmpty ? null : () => _pick(widget.parts, 'part'), icon: const Icon(Icons.settings_input_component_outlined, size: 18), label: Text(context.tr('estimate.addPart'), overflow: TextOverflow.ellipsis))),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(flex: 3, child: TextField(controller: _customName, decoration: InputDecoration(hintText: context.tr('estimate.customName')))),
        const SizedBox(width: 8),
        Expanded(flex: 2, child: TextField(controller: _customPrice, keyboardType: TextInputType.number, decoration: InputDecoration(hintText: context.tr('common.price')))),
        const SizedBox(width: 8),
        IconButton.filledTonal(
          onPressed: () {
            if (_customName.text.trim().isEmpty) return;
            setState(() => _lines.add(_Draft(kind: 'labor', name: _customName.text.trim(), unitPrice: double.tryParse(_customPrice.text.replaceAll(' ', '')) ?? 0)));
            _customName.clear();
            _customPrice.clear();
          },
          icon: const Icon(Icons.add),
          tooltip: context.tr('estimate.addLabor'),
        ),
      ]),
      const SizedBox(height: 12),
      if (_lines.isEmpty) Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)), child: Text(context.tr('estimate.empty'), textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280)))),
      for (var i = 0; i < _lines.length; i++) _lineTile(i),
      Labeled(context.tr('estimate.note'), child: TextField(controller: _note, maxLines: 2, maxLength: 500)),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: Brand.purpleTint, borderRadius: BorderRadius.circular(12)),
        child: Text('${context.tr('estimate.total')}: ${formatMoney(_total)}${_optionalTotal > 0 ? '  + ${formatMoney(_optionalTotal)} ${context.tr('estimate.ifChosen')}' : ''}', style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF5A0085))),
      ),
      const SizedBox(height: 12),
      BusyButton(label: context.tr('estimate.saveSend'), icon: Icons.send_outlined, enabled: _lines.isNotEmpty, onPressed: () => _submit(true)),
      if (widget.allowDraft) ...[const SizedBox(height: 8), BusyButton(label: context.tr('estimate.saveDraft'), outlined: true, enabled: _lines.isNotEmpty, onPressed: () => _submit(false))],
    ]);
  }

  Widget _lineTile(int i) {
    final line = _lines[i];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border.all(color: Brand.border), borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(line.name, style: const TextStyle(fontWeight: FontWeight.w800)), Text(context.tr('estimate.kind.${line.kind}'), style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))])),
          IconButton(onPressed: () => setState(() => _lines.removeAt(i)), icon: const Icon(Icons.delete_outline), tooltip: context.tr('common.remove')),
        ]),
        Row(children: [
          if (line.kind != 'service') ...[
            IconButton(onPressed: line.quantity > 1 ? () => setState(() => line.quantity--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('${line.quantity}', style: const TextStyle(fontWeight: FontWeight.w900)),
            IconButton(onPressed: line.quantity < 99 ? () => setState(() => line.quantity++) : null, icon: const Icon(Icons.add_circle_outline)),
          ],
          const Spacer(),
          Text(formatMoney(line.unitPrice * line.quantity), style: const TextStyle(fontWeight: FontWeight.w800)),
        ]),
        CheckboxListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: line.optional,
          onChanged: (v) => setState(() => line.optional = v ?? false),
          title: Text(context.tr('estimate.optional'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ]),
    );
  }
}

/// A read-only estimate with its status, lines and total.
class EstimateCard extends StatelessWidget {
  const EstimateCard({super.key, required this.estimate, this.actions = const []});
  final Estimate estimate;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final approved = estimate.status == 'approved';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFFAFAFA), borderRadius: BorderRadius.circular(14), border: Border.all(color: Brand.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pill(context.tr('estimate.status.${estimate.status}'), color: approved ? Brand.green : (estimate.status == 'declined' || estimate.status == 'expired' ? Brand.red : Brand.purple), background: approved ? Brand.greenTint : (estimate.status == 'declined' || estimate.status == 'expired' ? Brand.redTint : Brand.purpleTint)),
          const Spacer(),
          if (estimate.validUntil != null && estimate.status == 'sent') Text('${context.tr('estimate.validUntil')} ${formatStamp(estimate.validUntil)}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
        ]),
        if (estimate.note != null && estimate.note!.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text(estimate.note!, style: const TextStyle(fontSize: 13))),
        const SizedBox(height: 8),
        for (final line in estimate.lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(text: line.label(locale)),
                  if (line.quantity > 1) TextSpan(text: ' × ${line.quantity}', style: const TextStyle(color: Color(0xFF6B7280))),
                  if (line.isOptional) TextSpan(text: '  ${context.tr('estimate.optional')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF6B7280))),
                  if (line.kind == 'part' && approved && line.isSelected && !line.isFulfilled) TextSpan(text: '  ${context.tr('estimate.onOrder')}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Brand.amberText)),
                ]), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, decoration: approved && !line.isSelected ? TextDecoration.lineThrough : null, color: approved && !line.isSelected ? const Color(0xFF9CA3AF) : Brand.ink)),
              ),
              Text(formatMoney(line.total), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ]),
          ),
        const Divider(),
        Row(children: [Text(context.tr('estimate.total'), style: const TextStyle(fontWeight: FontWeight.w900)), const Spacer(), Text(formatMoney(estimate.total), style: const TextStyle(fontWeight: FontWeight.w900))]),
        if (estimate.status == 'declined' && estimate.declineReason != null && estimate.declineReason!.isNotEmpty)
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('estimate.declinedBecause', params: {'reason': estimate.declineReason}), style: const TextStyle(color: Brand.red, fontSize: 12, fontWeight: FontWeight.w700))),
        if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: actions)),
      ]),
    );
  }
}
