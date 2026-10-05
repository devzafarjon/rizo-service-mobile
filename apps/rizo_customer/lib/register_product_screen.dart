import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Add a product bought somewhere else, so its warranty and service history live in one place.
class RegisterProductScreen extends StatefulWidget {
  const RegisterProductScreen({super.key});
  @override
  State<RegisterProductScreen> createState() => _RegisterProductScreenState();
}

class _RegisterProductScreenState extends State<RegisterProductScreen> {
  List<ProductRef> products = [];
  String? productId;
  DateTime? purchaseDate;
  final _serial = TextEditingController();
  final _invoice = TextEditingController();
  bool loading = true;

  ApiClient get _api => context.read<CustomerSession>().api;

  @override
  void initState() {
    super.initState();
    _api.get('/api/customer/products').then((r) {
      if (mounted) {
        setState(() {
          products = asList(asMap(r)['products']).map(ProductRef.fromJson).toList();
          loading = false;
        });
      }
    }).catchError((Object e) {
      if (mounted) {
        setState(() => loading = false);
        showSnack(context, context.errorText(e), error: true);
      }
    });
  }

  Future<void> _submit() async {
    if (productId == null || _serial.text.trim().isEmpty || purchaseDate == null) {
      showSnack(context, context.tr('errors.required'), error: true);
      return;
    }
    try {
      await _api.post('/api/customer/sales/register', body: {
        'productId': productId,
        'serialNumber': _serial.text.trim(),
        'purchaseDate': isoDate(purchaseDate!),
        if (_invoice.text.trim().isNotEmpty) 'invoiceNumber': _invoice.text.trim(),
      });
      if (!mounted) return;
      showSnack(context, context.tr('register.saved'));
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('register.title'))),
      body: loading
          ? const LoadingView()
          : ListView(padding: const EdgeInsets.all(16), children: [
              Text(context.tr('register.intro'), style: const TextStyle(color: Color(0xFF6B7280))),
              const SizedBox(height: 16),
              Labeled(context.tr('common.product'), child: DropdownButtonFormField<String?>(initialValue: productId, isExpanded: true, hint: Text(context.tr('register.selectProduct')), items: [for (final p in products) DropdownMenuItem<String?>(value: p.id, child: Text('${p.name(locale)} · ${p.sku}', overflow: TextOverflow.ellipsis))], onChanged: (v) => setState(() => productId = v))),
              Labeled(context.tr('serial.label'), hint: context.tr('register.serialHint'), child: TextField(controller: _serial)),
              Labeled(
                context.tr('register.purchaseDate'),
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final now = DateTime.now();
                    final d = await showDatePicker(context: context, initialDate: purchaseDate ?? now, firstDate: DateTime(now.year - 15), lastDate: now);
                    if (d != null) setState(() => purchaseDate = d);
                  },
                  icon: const Icon(Icons.event_outlined),
                  label: Text(purchaseDate == null ? context.tr('common.dash') : formatDate(isoDate(purchaseDate!))),
                ),
              ),
              Labeled('${context.tr('register.invoice')} (${context.tr('common.optional')})', hint: context.tr('register.invoiceHint'), child: TextField(controller: _invoice)),
              Container(padding: const EdgeInsets.all(12), margin: const EdgeInsets.only(bottom: 14), decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)), child: Text(context.tr('register.verifyNote'), style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)))),
              BusyButton(label: context.tr('register.submit'), onPressed: _submit),
            ]),
    );
  }
}
