import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'new_request_screen.dart';
import 'register_product_screen.dart';

/// The customer's products: warranty countdown, booking service and paid warranty extensions.
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<PortalSale> sales = [];
  Object? error;
  bool loading = true;

  ApiClient get _api => context.read<CustomerSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.get('/api/customer/sales');
      if (mounted) setState(() => sales = asList(asMap(r)['sales']).map(PortalSale.new).where((s) => !s.voided).toList());
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _extend(PortalSale sale) async {
    final locale = Translator.I.locale;
    Json data;
    try {
      data = asMap(await _api.get('/api/customer/warranty-plans', query: {'saleId': sale.id}));
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
      return;
    }
    if (!mounted) return;
    final plans = asList(data['plans']).map(WarrantyPlanInfo.new).toList();
    final requestedId = data['requestedPlanId']?.toString();
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sheet.tr('products.extendTitle'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            if (plans.isEmpty)
              Text(sheet.tr('products.noPlans'), style: TextStyle(color: Brand.muted))
            else ...[
              Text(sheet.tr('products.extendBody'), style: TextStyle(color: Brand.muted)),
              const SizedBox(height: 12),
              for (final plan in plans)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(plan.names.localized(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(formatMoney(plan.price)),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                      onPressed: requestedId != null ? null : () => Navigator.of(sheet).pop(plan.id),
                      child: Text(requestedId == plan.id ? sheet.tr('products.asked') : sheet.tr('products.ask')),
                    ),
                  ),
                ),
              Text(sheet.tr('products.payAtService'), style: TextStyle(color: Brand.muted, fontSize: 12)),
            ],
          ]),
        ),
      ),
    );
    if (chosen == null || !mounted) return;
    final asked = context.tr('plans.requested');
    try {
      await _api.post('/api/customer/sales/${sale.id}/warranty-plan', body: {'planId': chosen});
      if (mounted) showSnack(context, asked);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('products.title')), actions: [
        IconButton(
          tooltip: context.tr('nav.registerProduct'),
          icon: const Icon(Icons.add_box_outlined),
          onPressed: () async {
            await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterProductScreen()));
            _load();
          },
        ),
      ]),
      body: loading
          ? const LoadingView()
          : error != null && sales.isEmpty
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: sales.isEmpty
                      ? ListView(children: [SizedBox(height: 320, child: EmptyView(title: context.tr('products.emptyTitle'), body: context.tr('products.emptyBody')))])
                      : ListView(padding: const EdgeInsets.all(14), children: [
                          Text(context.tr('products.intro'), style: TextStyle(color: Brand.muted)),
                          const SizedBox(height: 12),
                          for (final sale in sales) _card(sale, locale),
                        ]),
                ),
    );
  }

  Widget _card(PortalSale sale, String locale) {
    final inWarranty = sale.warrantyStatus == 'in_warranty';
    final left = sale.warrantyDaysLeft;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(sale.product.name(locale), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
            WarrantyChip(sale.warrantyStatus),
          ]),
          Text('${sale.product.sku} · ${sale.invoiceNumber}${sale.serialNumber != null ? ' · ${context.tr('serial.label')}: ${sale.serialNumber}' : ''}', style: TextStyle(color: Brand.muted, fontSize: 12)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(inWarranty ? context.tr('products.warrantyUntil', params: {'date': formatDate(sale.warrantyExpiry)}) : context.tr('products.warrantyEnded', params: {'date': formatDate(sale.warrantyExpiry)})),
            if (left != null && left >= 0 && left <= 60) Pill(context.tr('products.daysLeft', params: {'count': left}), color: Brand.amberText, background: Brand.amberTint),
          ]),
          if (!sale.isVerified) Padding(padding: const EdgeInsets.only(top: 4), child: Text(context.tr('products.unverified'), style: TextStyle(color: Brand.muted, fontSize: 12))),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => NewRequestScreen(initialSaleId: sale.id))),
              child: Text(context.tr('products.bookService')),
            ),
            OutlinedButton.icon(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)), onPressed: () => _extend(sale), icon: const Icon(Icons.verified_user_outlined), label: Text(context.tr('products.extend'))),
          ]),
        ]),
      ),
    );
  }
}
