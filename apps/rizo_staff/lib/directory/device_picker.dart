import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Brands and models are compared without case, spaces or punctuation: "Samsung", "samsung" and "SAM-SUNG" are one brand.
String directoryKey(String text) => text.toLowerCase().replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), '');

/// A category name in the current language (the same `categories.<name>` keys as the website).
String categoryLabel(String category) => tr('categories.$category', def: category);

ApiClient _api(BuildContext context) => context.read<StaffSession>().api;

Future<List<DirBrand>> loadBrands(BuildContext context) async => asList(asMap(await _api(context).get('/api/staff/directory/brands'))['brands']).map((m) => DirBrand(asMap(m))).toList();

Future<List<DirModel>> loadModels(BuildContext context, {String? brandId, String? category, bool pending = false}) async {
  final r = await _api(context).get('/api/staff/directory/models', query: {if (brandId != null && brandId.isNotEmpty) 'brandId': brandId, if (category != null && category.isNotEmpty) 'category': category, if (pending) 'approved': 'false'});
  return asList(asMap(r)['models']).map((m) => DirModel(asMap(m))).toList();
}

Future<List<String>> loadCategories(BuildContext context) async {
  final raw = asMap(await _api(context).get('/api/staff/directory/categories'))['categories'];
  return raw is List ? raw.map((e) => e.toString()).toList() : <String>[];
}

List<Map<String, dynamic>> _similar(ApiException e) => e.details?['similar'] is List ? asList(e.details!['similar']).map(asMap).toList() : const [];

/// Adds a model of another maker: brand (existing or new), category and model.
/// Near-duplicates are shown first; only an admin's own entry is approved at once.
Future<DirModel?> showAddDeviceSheet(BuildContext context, {String? presetBrandId, String? presetCategory}) {
  return showModalBottomSheet<DirModel>(context: context, isScrollControlled: true, showDragHandle: true, builder: (_) => _AddDeviceSheet(presetBrandId: presetBrandId, presetCategory: presetCategory));
}

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet({this.presetBrandId, this.presetCategory});
  final String? presetBrandId;
  final String? presetCategory;
  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _brand = TextEditingController();
  final _model = TextEditingController();
  List<DirBrand> brands = [];
  List<String> categories = [];
  String? category;
  List<Map<String, dynamic>> similar = [];
  String similarKind = 'brand';

  @override
  void initState() {
    super.initState();
    category = widget.presetCategory;
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([loadBrands(context), loadCategories(context)]);
      if (!mounted) return;
      setState(() {
        brands = (results[0] as List<DirBrand>).where((b) => !b.isOwn).toList();
        categories = results[1] as List<String>;
        final preset = brands.where((b) => b.id == widget.presetBrandId);
        if (preset.isNotEmpty) _brand.text = preset.first.name;
      });
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  Future<void> _save({bool force = false}) async {
    final api = _api(context);
    final key = directoryKey(_brand.text);
    if (key.isEmpty || category == null || directoryKey(_model.text).isEmpty) return showSnack(context, tr('directory.pickModel'), error: true);
    try {
      DirBrand? brand;
      for (final b in brands) {
        if (directoryKey(b.name) == key) brand = b;
      }
      if (brand == null) {
        try {
          final r = asMap(await api.post('/api/staff/directory/brands', body: {'name': _brand.text.trim(), 'force': force}));
          brand = DirBrand(asMap(r['brand']));
        } on ApiException catch (e) {
          if (e.code == 'similarBrand') return setState(() { similar = _similar(e); similarKind = 'brand'; });
          rethrow;
        }
      }
      try {
        final r = asMap(await api.post('/api/staff/directory/models', body: {'brandId': brand.id, 'category': category, 'model': _model.text.trim(), 'force': force}));
        if (mounted) Navigator.pop(context, DirModel(asMap(r['model'])));
      } on ApiException catch (e) {
        if (e.code == 'similarModel') return setState(() { similar = _similar(e); similarKind = 'model'; });
        rethrow;
      }
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<StaffSession>().user?.isAdmin ?? false;
    final typed = directoryKey(_brand.text);
    final suggestions = typed.isEmpty ? <DirBrand>[] : brands.where((b) => directoryKey(b.name).contains(typed) && directoryKey(b.name) != typed).take(5).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(context.tr('directory.addDevice'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(isAdmin ? context.tr('directory.addHintAdmin') : context.tr('directory.addHint'), style: TextStyle(color: Brand.muted, fontSize: 13)),
          const SizedBox(height: 14),
          Labeled(context.tr('directory.brand'), child: TextField(controller: _brand, maxLength: 60, onChanged: (_) => setState(() => similar = []), decoration: InputDecoration(hintText: context.tr('directory.brandPlaceholder'), counterText: ''))),
          if (suggestions.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 12), child: Wrap(spacing: 8, children: [for (final b in suggestions) ActionChip(label: Text(b.name), onPressed: () => setState(() => _brand.text = b.name))])),
          Labeled(
            context.tr('directory.category'),
            child: DropdownButtonFormField<String?>(
              initialValue: category,
              isExpanded: true,
              hint: Text(context.tr('directory.chooseCategory')),
              items: [for (final c in categories) DropdownMenuItem<String?>(value: c, child: Text(categoryLabel(c)))],
              onChanged: (v) => setState(() => category = v),
            ),
          ),
          Labeled(context.tr('directory.model'), child: TextField(controller: _model, maxLength: 80, onChanged: (_) => setState(() => similar = []), decoration: InputDecoration(hintText: context.tr('directory.modelPlaceholder'), counterText: ''))),
          if (similar.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Brand.amberTint, borderRadius: BorderRadius.circular(12)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(context.tr(similarKind == 'brand' ? 'directory.similarBrand' : 'directory.similarModel'), style: TextStyle(color: Brand.amberText, fontWeight: FontWeight.w800)),
                for (final s in similar) Text('• ${s['name']}', style: TextStyle(color: Brand.amberText)),
                const SizedBox(height: 6),
                Text(context.tr('directory.similarHint'), style: TextStyle(color: Brand.amberText, fontSize: 12)),
                TextButton(onPressed: () => _save(force: true), child: Text(context.tr('directory.addAnyway'))),
              ]),
            ),
          BusyButton(label: context.tr('directory.add'), icon: Icons.add, onPressed: _save),
        ]),
      ),
    );
  }
}

/// Category, then brand, then model of a device by another maker. Models waiting for approval are listed but cannot be chosen.
class OtherDevicePicker extends StatefulWidget {
  const OtherDevicePicker({super.key, required this.value, required this.onChanged});
  final DirModel? value;
  final ValueChanged<DirModel?> onChanged;
  @override
  State<OtherDevicePicker> createState() => _OtherDevicePickerState();
}

class _OtherDevicePickerState extends State<OtherDevicePicker> {
  List<String> categories = [];
  List<DirBrand> brands = [];
  List<DirModel> models = [];
  String? category;
  String? brandId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([loadCategories(context), loadBrands(context)]);
      if (!mounted) return;
      setState(() {
        categories = results[0] as List<String>;
        brands = (results[1] as List<DirBrand>).where((b) => !b.isOwn).toList();
      });
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  Future<void> _loadModels() async {
    if (brandId == null || category == null) return setState(() => models = []);
    try {
      final list = await loadModels(context, brandId: brandId, category: category);
      if (mounted) setState(() => models = list);
    } catch (e) {
      if (mounted) showSnack(context, Translator.I.errorMessage(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shownBrands = brands.where((b) => category == null || b.categories.contains(category) || !b.approved).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Labeled(
        context.tr('directory.category'),
        child: DropdownButtonFormField<String?>(
          initialValue: category,
          isExpanded: true,
          hint: Text(context.tr('directory.chooseCategory')),
          items: [for (final c in categories) DropdownMenuItem<String?>(value: c, child: Text(categoryLabel(c)))],
          onChanged: (v) {
            setState(() { category = v; brandId = null; models = []; });
            widget.onChanged(null);
          },
        ),
      ),
      Labeled(
        context.tr('directory.brand'),
        child: DropdownButtonFormField<String?>(
          key: ValueKey('brand-$category'),
          initialValue: brandId,
          isExpanded: true,
          hint: Text(context.tr('directory.chooseBrand')),
          items: [for (final b in shownBrands) DropdownMenuItem<String?>(value: b.id, child: Text(b.approved ? b.name : '${b.name} (${context.tr('directory.pending')})'))],
          onChanged: category == null ? null : (v) {
            setState(() => brandId = v);
            widget.onChanged(null);
            _loadModels();
          },
        ),
      ),
      Labeled(
        context.tr('directory.model'),
        child: DropdownButtonFormField<String?>(
          key: ValueKey('model-$brandId-${models.length}'),
          initialValue: models.any((m) => m.id == widget.value?.id) ? widget.value?.id : null,
          isExpanded: true,
          hint: Text(context.tr('directory.chooseModel')),
          items: [for (final m in models) DropdownMenuItem<String?>(value: m.id, enabled: m.approved, child: Text(m.approved ? m.name : '${m.name} (${context.tr('directory.pending')})', overflow: TextOverflow.ellipsis))],
          onChanged: brandId == null ? null : (v) => widget.onChanged(models.cast<DirModel?>().firstWhere((m) => m!.id == v, orElse: () => null)),
        ),
      ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () async {
            final added = await showAddDeviceSheet(context, presetBrandId: brandId, presetCategory: category);
            if (added == null || !mounted) return;
            await _load();
            setState(() { category = added.category; brandId = added.brandId; });
            await _loadModels();
            if (added.approved) widget.onChanged(added);
          },
          icon: const Icon(Icons.add),
          label: Text(context.tr('directory.notInList')),
        ),
      ),
      Text(context.tr('directory.otherMakerNote'), style: TextStyle(color: Brand.muted, fontSize: 12)),
      const SizedBox(height: 12),
    ]);
  }
}
