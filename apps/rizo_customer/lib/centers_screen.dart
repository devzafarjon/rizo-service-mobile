import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Service centers: where to take a device. Open without signing in.
class CentersScreen extends StatefulWidget {
  const CentersScreen({super.key});
  @override
  State<CentersScreen> createState() => _CentersScreenState();
}

class _CentersScreenState extends State<CentersScreen> {
  List<ServiceCenter> items = [];
  Object? error;
  bool loading = true;
  final _api = ApiClient();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => error = null);
    try {
      final r = await _api.get('/api/public/centers');
      if (mounted) setState(() => items = asList(asMap(r)['centers']).map(ServiceCenter.new).toList());
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('centers.public.title')), actions: const [LanguageButton()]),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.all(14), children: [
                    Text(context.tr('centers.public.intro'), style: const TextStyle(color: Color(0xFF6B7280))),
                    const SizedBox(height: 12),
                    if (items.isEmpty) SizedBox(height: 240, child: EmptyView(title: context.tr('centers.emptyTitle'))),
                    for (final c in items)
                      Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [Expanded(child: Text(c.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900))), if (c.isAuthorized) Pill(context.tr('centers.authorized'), color: Brand.purple, background: Brand.purpleTint)]),
                            const SizedBox(height: 6),
                            Text(c.address),
                            if (c.workingHours != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(c.workingHours!, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13))),
                            const SizedBox(height: 8),
                            Row(children: [
                              if (c.phone != null) Expanded(child: OutlinedButton.icon(onPressed: () => openUri(context, telUri(c.phone!)), icon: const Icon(Icons.call_outlined, size: 18), label: Text(formatPhone(c.phone!), overflow: TextOverflow.ellipsis))),
                              if (c.phone != null) const SizedBox(width: 8),
                              Expanded(child: OutlinedButton.icon(onPressed: () => openUri(context, GeoLocation(address: c.address, lat: c.lat, lng: c.lng).mapsUri), icon: const Icon(Icons.navigation_outlined, size: 18), label: Text(context.tr('maps.directions')))),
                            ]),
                          ]),
                        ),
                      ),
                  ]),
                ),
    );
  }
}
