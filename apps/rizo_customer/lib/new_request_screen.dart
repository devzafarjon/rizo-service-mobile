import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Book a repair or an installation in three steps: what, describe, where.
class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});
  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  int step = 0;
  String type = 'repair';
  List<PortalSale> sales = [];
  List<ProductRef> products = [];
  List<ServiceCenter> centers = [];
  String? saleId;
  String? productId;
  bool otherProduct = false;
  String defectType = 'failed_during_use';
  String locationType = 'in_shop';
  String? centerId;
  DateTime? preferred;
  final photos = <Uint8List>[];
  final _issue = TextEditingController();
  final _serial = TextEditingController();
  final _address = TextEditingController();
  bool ready = false;

  ApiClient get _api => context.read<CustomerSession>().api;
  bool get _onSite => locationType == 'on_site' || type == 'installation';

  @override
  void initState() {
    super.initState();
    _address.text = context.read<CustomerSession>().user?.address ?? '';
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([_api.get('/api/customer/sales'), _api.get('/api/customer/products'), _api.get('/api/public/centers').catchError((_) => <String, dynamic>{'centers': []})]);
      if (!mounted) return;
      setState(() {
        sales = asList(asMap(results[0])['sales']).map(PortalSale.new).toList();
        products = asList(asMap(results[1])['products']).map(ProductRef.fromJson).toList();
        centers = asList(asMap(results[2])['centers']).map(ServiceCenter.new).toList();
        otherProduct = sales.isEmpty;
        ready = true;
      });
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  bool get _stepOk => switch (step) {
        0 => otherProduct ? productId != null : saleId != null,
        1 => _issue.text.trim().isNotEmpty,
        _ => !_onSite || _address.text.trim().isNotEmpty,
      };

  Future<void> _submit() async {
    try {
      final r = await _api.post('/api/customer/requests', body: {
        'type': type,
        if (!otherProduct && saleId != null) 'saleId': saleId,
        if (otherProduct && productId != null) 'productId': productId,
        'issueDescription': _issue.text.trim(),
        if (type == 'repair') 'defectType': defectType,
        'locationType': _onSite ? 'on_site' : 'in_shop',
        if (_onSite) 'customerLocation': {'address': _address.text.trim()},
        if (_serial.text.trim().isNotEmpty) 'serialNumber': _serial.text.trim(),
        if (centerId != null && !_onSite) 'serviceCenterId': centerId,
        if (preferred != null) 'scheduledAt': preferred!.toUtc().toIso8601String(),
      });
      final id = asMap(asMap(r)['request'])['id'].toString();
      if (photos.isNotEmpty) {
        try {
          await _api.upload('/api/customer/requests/$id/photos', [for (var i = 0; i < photos.length; i++) UploadFile('photo-$i.jpg', photos[i])]);
        } catch (_) {
          if (mounted) showSnack(context, context.tr('errors.uploadFailed'), error: true);
        }
      }
      if (!mounted) return;
      showSnack(context, context.tr('portal.created'));
      Navigator.of(context).pop(id);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('portal.newTitle'))),
      body: !ready
          ? const LoadingView()
          : Column(children: [
              LinearProgressIndicator(value: (step + 1) / 3, minHeight: 4, color: Brand.purple, backgroundColor: Brand.purpleTint),
              Expanded(
                child: ListView(padding: const EdgeInsets.all(16), children: [
                  Text(context.tr('common.stepOf', params: {'current': step + 1, 'total': 3}).toUpperCase(), style: TextStyle(color: Brand.purple, fontWeight: FontWeight.w900, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(context.tr('portal.step${step + 1}Title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 16),
                  if (step == 0) ..._stepOne(locale),
                  if (step == 1) ..._stepTwo(),
                  if (step == 2) ..._stepThree(locale),
                ]),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(children: [
                    if (step > 0) Expanded(child: OutlinedButton(onPressed: () => setState(() => step--), child: Text(context.tr('common.back')))),
                    if (step > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: step < 2
                          ? FilledButton(onPressed: _stepOk ? () => setState(() => step++) : null, child: Text(context.tr('common.next')))
                          : BusyButton(label: context.tr('portal.submit'), icon: Icons.send, enabled: _stepOk, onPressed: _submit),
                    ),
                  ]),
                ),
              ),
            ]),
    );
  }

  List<Widget> _stepOne(String locale) {
    return [
      for (final t in ['repair', 'installation'])
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: type == t ? Brand.purpleTint : Brand.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: type == t ? Brand.purple : Brand.border, width: type == t ? 2 : 1)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => setState(() {
                type = t;
                if (t == 'installation') locationType = 'on_site';
              }),
              child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [Icon(t == 'repair' ? Icons.build_outlined : Icons.handyman_outlined, color: Brand.purple), const SizedBox(width: 14), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(context.tr('type.$t'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)), Text(context.tr('portal.hint.$t'), style: TextStyle(fontSize: 13, color: Brand.muted))]))])),
            ),
          ),
        ),
      const SizedBox(height: 8),
      if (sales.isNotEmpty && !otherProduct)
        Labeled(
          context.tr('portal.purchase'),
          child: DropdownButtonFormField<String?>(
            initialValue: saleId,
            isExpanded: true,
            hint: Text(context.tr('portal.selectPurchase')),
            items: [for (final s in sales) DropdownMenuItem<String?>(value: s.id, child: Text('${s.product.name(locale)} · ${s.invoiceNumber}', overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() {
              saleId = v;
              final s = sales.cast<PortalSale?>().firstWhere((x) => x!.id == v, orElse: () => null);
              if (s?.serialNumber != null && _serial.text.isEmpty) _serial.text = s!.serialNumber!;
            }),
          ),
        ),
      if (sales.isEmpty) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(context.tr('portal.noPurchases'), style: TextStyle(color: Brand.muted))),
      if (otherProduct)
        Labeled(
          context.tr('common.product'),
          child: DropdownButtonFormField<String?>(
            initialValue: productId,
            isExpanded: true,
            hint: Text(context.tr('portal.selectProduct')),
            items: [for (final p in products) DropdownMenuItem<String?>(value: p.id, child: Text(p.name(locale), overflow: TextOverflow.ellipsis))],
            onChanged: (v) => setState(() => productId = v),
          ),
        ),
      if (sales.isNotEmpty)
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: otherProduct,
          onChanged: (v) => setState(() {
            otherProduct = v ?? false;
            saleId = null;
            productId = null;
          }),
          title: Text(context.tr('portal.otherProduct'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
    ];
  }

  List<Widget> _stepTwo() {
    return [
      Labeled(context.tr('portal.describeIssue'), child: TextField(controller: _issue, maxLines: 5, minLines: 4, onChanged: (_) => setState(() {}), decoration: InputDecoration(hintText: context.tr('portal.issuePlaceholder')))),
      if (type == 'repair') Labeled(context.tr('portal.whatHappened'), child: SegmentedChoice<String>(value: defectType, options: {'dead_on_arrival': context.tr('defect.dead_on_arrival'), 'failed_during_use': context.tr('defect.failed_during_use')}, onChanged: (v) => setState(() => defectType = v))),
      Labeled(context.tr('serial.label'), hint: context.tr('serial.portalHint'), child: TextField(controller: _serial)),
      Labeled(
        context.tr('portal.addPhotos'),
        hint: context.tr('portal.addPhotosHint'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SizedBox(
                height: 84,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (var i = 0; i < photos.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(children: [
                        ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(photos[i], width: 84, height: 84, fit: BoxFit.cover)),
                        Positioned(right: 2, top: 2, child: InkWell(onTap: () => setState(() => photos.removeAt(i)), child: Container(padding: const EdgeInsets.all(4), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.close, size: 14, color: Colors.white)))),
                      ]),
                    ),
                ]),
              ),
            ),
          PhotoPickerBar(onPicked: (list) async => setState(() => photos.addAll(list.take(8 - photos.length)))),
          if (photos.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text(context.tr('portal.photoCount', count: photos.length), style: TextStyle(fontSize: 12, color: Brand.muted))),
        ]),
      ),
    ];
  }

  List<Widget> _stepThree(String locale) {
    return [
      if (type == 'repair') Labeled(context.tr('portal.where'), child: SegmentedChoice<String>(value: locationType, options: {'in_shop': context.tr('location.in_shop'), 'on_site': context.tr('location.on_site')}, onChanged: (v) => setState(() => locationType = v))),
      if (type == 'installation') Padding(padding: const EdgeInsets.only(bottom: 14), child: Text(context.tr('portal.installationOnlyOnSite'), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w700))),
      if (_onSite) Labeled(context.tr('common.address'), child: TextField(controller: _address, maxLines: 2, minLines: 1, onChanged: (_) => setState(() {}))),
      if (!_onSite && centers.isNotEmpty)
        Labeled(context.tr('centers.center'), hint: context.tr('centers.pickHint'), child: DropdownButtonFormField<String?>(initialValue: centerId, isExpanded: true, items: [DropdownMenuItem<String?>(value: null, child: Text(context.tr('centers.auto'))), for (final c in centers) DropdownMenuItem<String?>(value: c.id, child: Text('${c.name} · ${c.address}', overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => centerId = v))),
      Labeled(
        _onSite ? context.tr('portal.preferredTime') : context.tr('portal.preferredVisit'),
        hint: context.tr('portal.preferredTimeHint'),
        child: OutlinedButton.icon(
          onPressed: () async {
            final picked = await pickDateTime(context, initial: preferred);
            if (picked != null) setState(() => preferred = picked);
          },
          icon: const Icon(Icons.event_outlined),
          label: Text(preferred == null ? context.tr('common.dash') : formatStamp(preferred)),
        ),
      ),
      const SizedBox(height: 8),
      Section(
        title: context.tr('portal.review'),
        child: Column(children: [
          InfoRow(context.tr('common.type'), context.tr('type.$type')),
          InfoRow(context.tr('common.product'), otherProduct ? (products.cast<ProductRef?>().firstWhere((p) => p!.id == productId, orElse: () => null)?.name(locale)) : (sales.cast<PortalSale?>().firstWhere((s) => s!.id == saleId, orElse: () => null)?.product.name(locale))),
          InfoRow(context.tr('portal.describeIssue'), _issue.text.trim()),
          InfoRow(context.tr('detail.location'), context.tr('location.${_onSite ? 'on_site' : 'in_shop'}')),
        ]),
      ),
    ];
  }
}
