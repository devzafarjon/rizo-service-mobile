import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'device_picker.dart';

/// The technician's "I repair" list: whole brands or single models of other makers.
/// RIZO products and warranty jobs need no entry. An admin opens it for a technician with [staffId].
class SkillsScreen extends StatelessWidget {
  const SkillsScreen({super.key, this.staffId, this.title});
  final String? staffId;
  final String? title;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? context.tr('directory.mySkillsTitle'))),
      body: ListView(padding: const EdgeInsets.all(14), children: [
        if (staffId == null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(context.tr('directory.mySkillsIntro'), style: TextStyle(color: Brand.muted))),
        SkillsEditor(staffId: staffId),
      ]),
    );
  }
}

class SkillsEditor extends StatefulWidget {
  const SkillsEditor({super.key, this.staffId});
  final String? staffId;
  @override
  State<SkillsEditor> createState() => _SkillsEditorState();
}

class _SkillsEditorState extends State<SkillsEditor> {
  List<DirBrand> chosenBrands = [];
  List<DirModel> chosenModels = [];
  List<DirBrand> brands = [];
  List<DirModel> models = [];
  String? brandId;
  String? modelId;
  bool loading = true;
  Object? error;

  ApiClient get _api => context.read<StaffSession>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _apply(Object? response) {
    final r = asMap(response);
    chosenBrands = asList(r['brands']).map((m) => DirBrand(asMap(m))).toList();
    chosenModels = asList(r['models']).map((m) => DirModel(asMap(m))).toList();
  }

  Future<void> _load() async {
    try {
      final skills = await _api.get('/api/staff/directory/skills', query: {if (widget.staffId != null) 'staffId': widget.staffId});
      if (!mounted) return;
      final all = await loadBrands(context);
      if (!mounted) return;
      setState(() {
        _apply(skills);
        brands = all.where((b) => !b.isOwn).toList();
        loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { error = e; loading = false; });
    }
  }

  Future<void> _save(List<String> brandIds, List<String> productIds) async {
    try {
      final r = await _api.put('/api/staff/directory/skills', body: {if (widget.staffId != null) 'staffId': widget.staffId, 'brandIds': brandIds, 'productIds': productIds});
      if (mounted) setState(() => _apply(r));
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  Future<void> _addNew() async {
    final added = await showAddDeviceSheet(context);
    if (added == null || !mounted) return;
    await _save(_brandIds, {..._modelIds, added.id}.toList());
    if (!mounted) return;
    final all = await loadBrands(context);
    if (mounted) setState(() => brands = all.where((b) => !b.isOwn).toList());
  }

  List<String> get _brandIds => chosenBrands.map((b) => b.id).toList();
  List<String> get _modelIds => chosenModels.map((m) => m.id).toList();

  Future<void> _addSelected() async {
    if (brandId == null) return;
    if (modelId != null) {
      await _save(_brandIds, {..._modelIds, modelId!}.toList());
    } else {
      await _save({..._brandIds, brandId!}.toList(), _modelIds);
    }
    setState(() { brandId = null; modelId = null; models = []; });
  }

  Future<void> _pickBrand(String? id) async {
    setState(() { brandId = id; modelId = null; models = []; });
    if (id == null) return;
    try {
      final list = await loadModels(context, brandId: id);
      if (mounted) setState(() => models = list);
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Padding(padding: EdgeInsets.all(24), child: LoadingView());
    if (error != null) return ErrorView(error: error!, onRetry: _load);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(context.tr('directory.skillsIntro'), style: TextStyle(color: Brand.muted, fontSize: 13)),
      const SizedBox(height: 12),
      if (chosenBrands.isEmpty && chosenModels.isEmpty) Text(context.tr('directory.skillsEmpty'), style: TextStyle(color: Brand.faint)),
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final b in chosenBrands)
          InputChip(
            label: Text('${b.name} · ${context.tr('directory.allModels')}${b.approved ? '' : ' · ${context.tr('directory.pending')}'}'),
            backgroundColor: b.approved ? Brand.purpleTint : Brand.amberTint,
            onDeleted: () => _save(_brandIds.where((id) => id != b.id).toList(), _modelIds),
          ),
        for (final m in chosenModels)
          InputChip(
            label: Text('${m.name} · ${categoryLabel(m.category)}${m.approved ? '' : ' · ${context.tr('directory.pending')}'}'),
            backgroundColor: m.approved ? Brand.purpleTint : Brand.amberTint,
            onDeleted: () => _save(_brandIds, _modelIds.where((id) => id != m.id).toList()),
          ),
      ]),
      const SizedBox(height: 16),
      DropdownButtonFormField<String?>(
        key: ValueKey('b-$brandId'),
        initialValue: brandId,
        isExpanded: true,
        hint: Text(context.tr('directory.chooseBrand')),
        items: [for (final b in brands) DropdownMenuItem<String?>(value: b.id, child: Text(b.approved ? b.name : '${b.name} (${context.tr('directory.pending')})'))],
        onChanged: _pickBrand,
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<String?>(
        key: ValueKey('m-$brandId-${models.length}-$modelId'),
        initialValue: modelId,
        isExpanded: true,
        hint: Text(context.tr('directory.allModelsOfBrand')),
        items: [DropdownMenuItem<String?>(value: null, child: Text(context.tr('directory.allModelsOfBrand'))), for (final m in models) DropdownMenuItem<String?>(value: m.id, child: Text('${m.name} · ${categoryLabel(m.category)}', overflow: TextOverflow.ellipsis))],
        onChanged: brandId == null ? null : (v) => setState(() => modelId = v),
      ),
      const SizedBox(height: 10),
      FilledButton.icon(onPressed: brandId == null ? null : _addSelected, icon: const Icon(Icons.add), label: Text(context.tr('directory.addToList'))),
      TextButton(
        onPressed: _addNew,
        child: Text(context.tr('directory.notInList')),
      ),
    ]);
  }
}
