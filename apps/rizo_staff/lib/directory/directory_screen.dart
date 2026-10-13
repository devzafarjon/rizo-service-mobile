import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'device_picker.dart';

/// Brands and models of other makers. Everyone in the office reads and adds; only an admin approves, renames, merges or deletes.
class DirectoryScreen extends StatefulWidget {
  const DirectoryScreen({super.key});
  @override
  State<DirectoryScreen> createState() => _DirectoryScreenState();
}

class _DirectoryScreenState extends State<DirectoryScreen> {
  List<DirBrand> brands = [];
  List<DirModel> pendingModels = [];
  final Map<String, List<DirModel>> models = {};
  String? open;
  bool loading = true;
  Object? error;

  ApiClient get _api => context.read<StaffSession>().api;
  bool get _isAdmin => context.read<StaffSession>().user?.isAdmin ?? false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await loadBrands(context);
      if (!mounted) return;
      final pending = _isAdmin ? await loadModels(context, pending: true) : <DirModel>[];
      if (!mounted) return;
      setState(() {
        brands = list;
        pendingModels = pending;
        models.clear();
        error = null;
        loading = false;
      });
      if (open != null) await _loadModels(open!);
    } catch (e) {
      if (mounted) setState(() { error = e; loading = false; });
    }
  }

  Future<void> _loadModels(String brandId) async {
    try {
      final list = await loadModels(context, brandId: brandId);
      if (mounted) setState(() => models[brandId] = list);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  Future<void> _run(Future<void> Function() work) async {
    try {
      await work();
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  Future<String?> _chooseOne(String title, List<(String, String)> items) {
    return showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(title: Text(title), children: [for (final (id, label) in items) SimpleDialogOption(onPressed: () => Navigator.pop(ctx, id), child: Text(label))]),
    );
  }

  Future<void> _merge({required bool brand, required String id, required String name}) async {
    String? intoId;
    if (brand) {
      intoId = await _chooseOne(context.tr('directory.mergeTitle', params: {'name': name}), [for (final b in brands.where((b) => b.id != id)) (b.id, b.name)]);
    } else {
      final brandId = await _chooseOne(context.tr('directory.brand'), [for (final b in brands.where((b) => !b.isOwn)) (b.id, b.name)]);
      if (brandId == null || !mounted) return;
      final options = (await loadModels(context, brandId: brandId)).where((m) => m.id != id && !m.isOwn).toList();
      if (!mounted) return;
      intoId = await _chooseOne(context.tr('directory.mergeTitle', params: {'name': name}), [for (final m in options) (m.id, m.name)]);
    }
    if (intoId == null) return;
    await _run(() => _api.post('/api/staff/directory/${brand ? 'brands' : 'models'}/$id/merge', body: {'intoId': intoId}));
  }

  Future<void> _rename({required bool brand, required String id, required String name}) async {
    final text = await promptDialog(context, title: context.tr('directory.rename'), label: context.tr(brand ? 'directory.brand' : 'directory.model'), initial: name, maxLines: 1);
    if (text == null) return;
    await _run(() => _api.patch('/api/staff/directory/${brand ? 'brands' : 'models'}/$id', body: brand ? {'name': text} : {'model': text}));
  }

  Future<void> _delete({required bool brand, required String id, required String name}) async {
    if (!await confirmDialog(context, context.tr('directory.deleteTitle'), body: context.tr('directory.deleteBody', params: {'name': name}), confirmLabel: context.tr('directory.delete'))) return;
    await _run(() => _api.delete('/api/staff/directory/${brand ? 'brands' : 'models'}/$id'));
  }

  Widget _menu({required bool brand, required String id, required String name, required bool approved}) {
    return PopupMenuButton<String>(
      onSelected: (v) {
        switch (v) {
          case 'approve':
            _run(() => _api.post('/api/staff/directory/${brand ? 'brands' : 'models'}/$id/approve', body: {}));
          case 'rename':
            _rename(brand: brand, id: id, name: name);
          case 'merge':
            _merge(brand: brand, id: id, name: name);
          case 'delete':
            _delete(brand: brand, id: id, name: name);
        }
      },
      itemBuilder: (ctx) => [
        if (!approved) PopupMenuItem(value: 'approve', child: Text(ctx.tr('directory.approve'))),
        PopupMenuItem(value: 'rename', child: Text(ctx.tr('directory.rename'))),
        PopupMenuItem(value: 'merge', child: Text(ctx.tr('directory.merge'))),
        PopupMenuItem(value: 'delete', child: Text(ctx.tr('directory.delete'))),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final admin = _isAdmin;
    final waitingBrands = brands.where((b) => !b.approved).toList();
    final waitingModels = pendingModels.where((m) => !waitingBrands.any((b) => b.id == m.brandId)).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('directory.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final added = await showAddDeviceSheet(context);
          if (added != null) await _load();
        },
        icon: const Icon(Icons.add),
        label: Text(context.tr('directory.addDevice')),
      ),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(12, 12, 12, 90), children: [
                    Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.tr('directory.intro'), style: TextStyle(color: Brand.muted, fontSize: 13))),
                    if (admin && (waitingBrands.isNotEmpty || waitingModels.isNotEmpty))
                      Card(
                        color: Brand.amberTint,
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(context.tr('directory.waitingTitle', count: waitingBrands.length + waitingModels.length), style: TextStyle(fontWeight: FontWeight.w900, color: Brand.amberText)),
                            const SizedBox(height: 8),
                            for (final b in waitingBrands)
                              _WaitingRow(
                                title: '${context.tr('directory.brand')}: ${b.name}',
                                subtitle: [b.addedByName, if (b.pendingModels > 0) context.tr('directory.withModels', count: b.pendingModels)].whereType<String>().join(' · '),
                                onApprove: () => _run(() => _api.post('/api/staff/directory/brands/${b.id}/approve', body: {})),
                                onReject: () => _delete(brand: true, id: b.id, name: b.name),
                              ),
                            for (final m in waitingModels)
                              _WaitingRow(
                                title: '${context.tr('directory.model')}: ${m.name}',
                                subtitle: '${categoryLabel(m.category)} · ${m.addedByName ?? ''}',
                                onApprove: () => _run(() => _api.post('/api/staff/directory/models/${m.id}/approve', body: {})),
                                onReject: () => _delete(brand: false, id: m.id, name: m.name),
                              ),
                          ]),
                        ),
                      ),
                    if (brands.isEmpty) EmptyView(title: context.tr('directory.empty')),
                    for (final b in brands)
                      Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            key: PageStorageKey(b.id),
                            initiallyExpanded: open == b.id,
                            onExpansionChanged: (v) {
                              setState(() => open = v ? b.id : (open == b.id ? null : open));
                              if (v) _loadModels(b.id);
                            },
                            title: Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              Text(b.name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                              if (b.isOwn) Pill(context.tr('directory.own'), color: Brand.purple, background: Brand.purpleTint),
                              if (!b.approved) Pill(context.tr('directory.pending'), color: Brand.amberText, background: Brand.amberTint),
                            ]),
                            subtitle: Text(context.tr('directory.modelCount', count: b.modelCount)),
                            trailing: admin && !b.isOwn ? _menu(brand: true, id: b.id, name: b.name, approved: b.approved) : null,
                            children: [
                              if (!models.containsKey(b.id)) const Padding(padding: EdgeInsets.all(12), child: LoadingView()),
                              if (models[b.id]?.isEmpty ?? false) Padding(padding: const EdgeInsets.all(12), child: Text(context.tr('directory.noModels'), style: TextStyle(color: Brand.faint))),
                              for (final m in models[b.id] ?? <DirModel>[])
                                ListTile(
                                  dense: true,
                                  title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                  subtitle: Text([categoryLabel(m.category), if (!m.isOwn) context.tr('directory.requestsCount', count: m.requestsCount), if (!m.approved) context.tr('directory.pending'), if (m.addedByName != null) m.addedByName!].join(' · ')),
                                  trailing: admin && !m.isOwn ? _menu(brand: false, id: m.id, name: m.name, approved: m.approved) : null,
                                ),
                              if (b.isOwn) Padding(padding: const EdgeInsets.all(12), child: Text(context.tr('directory.ownNote'), style: TextStyle(color: Brand.faint, fontSize: 12))),
                            ],
                          ),
                        ),
                      ),
                  ]),
                ),
    );
  }
}

class _WaitingRow extends StatelessWidget {
  const _WaitingRow({required this.title, required this.subtitle, required this.onApprove, required this.onReject});
  final String title;
  final String subtitle;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Brand.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), if (subtitle.isNotEmpty) Text(subtitle, style: TextStyle(color: Brand.muted, fontSize: 12))])),
        IconButton(onPressed: onApprove, icon: Icon(Icons.check_circle, color: Brand.green), tooltip: context.tr('directory.approve')),
        IconButton(onPressed: onReject, icon: Icon(Icons.cancel_outlined, color: Brand.red), tooltip: context.tr('directory.reject')),
      ]),
    );
  }
}
