import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// "Samarqand", "Toshkent shahri" ...
String regionName(String code) => tr('regions.${code.isEmpty ? '00' : code}', def: code);

/// Pill colours of a transfer's state.
({Color fg, Color bg}) transferColors(String status) => switch (status) {
      'requested' => (fg: Brand.amberText, bg: Brand.amberTint),
      'shipped' => (fg: Brand.purple, bg: Brand.purpleTint),
      'received' => (fg: Brand.green, bg: Brand.greenTint),
      'rejected' => (fg: Brand.red, bg: Brand.redTint),
      _ => (fg: Brand.muted, bg: Brand.surfaceAlt),
    };

Widget transferPill(String status) {
  final c = transferColors(status);
  return Pill(tr('warehouse.status.$status'), color: c.fg, background: c.bg);
}

/// Where a part can come from, fastest first. The best one carries a badge; a warehouse that holds too few cannot be chosen.
class SourcePicker extends StatelessWidget {
  const SourcePicker({super.key, required this.options, required this.value, required this.onChanged, this.allowSupplier = true});
  final List<SourceOption> options;
  final String value;
  final ValueChanged<SourceOption> onChanged;
  final bool allowSupplier;

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    return Column(children: [
      for (final o in options)
        Builder(builder: (context) {
          final disabled = !o.selectable || (o.isSupplier && !allowSupplier);
          final selected = value == o.key;
          return Opacity(
            opacity: disabled ? 0.5 : 1,
            child: Card(
              margin: const EdgeInsets.only(bottom: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: selected ? Brand.purple : Brand.border, width: selected ? 2 : 1)),
              color: selected ? Brand.purpleTint : null,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: disabled ? null : () => onChanged(o),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? Brand.purple : Brand.muted, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                          Text(o.isSupplier ? context.tr('warehouse.source.supplier') : o.warehouseName, style: const TextStyle(fontWeight: FontWeight.w900)),
                          if (!o.isSupplier) Pill(context.tr('warehouse.kind.${o.warehouseKind}')) else if (o.supplierName != null) Text(o.supplierName!, style: TextStyle(color: Brand.muted, fontSize: 12)),
                          if (o.recommended) Pill(context.tr('warehouse.source.fastest'), color: Brand.green, background: Brand.greenTint),
                        ]),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (!o.isSupplier) regionName(o.regionCode),
                            if (!o.isSupplier) context.tr('warehouse.source.available', params: {'count': o.available}) + (o.enough ? '' : ' · ${context.tr('warehouse.source.notEnough')}'),
                            '${context.tr('warehouse.source.eta', params: {'count': o.etaDays})} (${formatDate(o.etaDate)})',
                          ].join(' · '),
                          style: TextStyle(color: Brand.muted, fontSize: 12.5),
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            ),
          );
        }),
    ]);
  }
}

/// The region codes of Uzbekistan used across the system (same as the website).
const regionCodes = ['01', '10', '20', '25', '30', '40', '50', '60', '70', '75', '80', '85', '90', '95'];
