import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Short guides for common problems, so a visit is not needed for something a customer can fix in five minutes.
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  List<HelpArticleInfo> articles = [];
  Object? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await context.read<CustomerSession>().api.get('/api/customer/help');
      if (mounted) setState(() => articles = asList(asMap(r)['articles']).map(HelpArticleInfo.new).toList());
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('help.title'))),
      body: loading
          ? const LoadingView()
          : error != null && articles.isEmpty
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: articles.isEmpty
                      ? ListView(children: [SizedBox(height: 320, child: EmptyView(title: context.tr('help.noneTitle'), body: context.tr('help.noneBody')))])
                      : ListView(padding: const EdgeInsets.all(14), children: [
                          Text(context.tr('help.intro'), style: TextStyle(color: Brand.muted)),
                          const SizedBox(height: 12),
                          for (final a in articles)
                            Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Theme(
                                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                child: ExpansionTile(
                                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                                  title: Text(a.titleFor(locale), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  children: [
                                    Text(a.bodyFor(locale)),
                                    if (a.videoUrl != null)
                                      TextButton.icon(onPressed: () => openUri(context, Uri.parse(a.videoUrl!)), icon: const Icon(Icons.play_circle_outline), label: Text(context.tr('help.watch'))),
                                  ],
                                ),
                              ),
                            ),
                        ]),
                ),
    );
  }
}
