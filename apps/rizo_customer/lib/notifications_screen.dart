import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'request_detail_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, required this.onChanged});
  final VoidCallback onChanged;
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Json> items = [];
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
      final r = await _api.get('/api/customer/notifications');
      if (mounted) {
        setState(() {
          items = asList(asMap(r)['notifications']);
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  static const _legacy = {'scheduled': 'new', 'received': 'new', 'repairing': 'in_progress', 'ready_for_pickup': 'ready', 'closed': 'completed'};

  /// Same wording as the website: translate from the notification's code and parameters.
  String _text(Json n) {
    final code = n['code']?.toString();
    final params = asMap(n['params']);
    if (code == null || code.isEmpty) return asString(n['message']);
    final product = Named(asString(params['productName'] ?? params['product']), nameUz: params['nameUz']?.toString(), nameRu: params['nameRu']?.toString(), nameEn: params['nameEn']?.toString()).localized(Translator.I.locale);
    final statusKey = params['status']?.toString();
    return tr('notify.$code', params: {
      ...params,
      'type': params['type'] == null ? '' : tr('type.${params['type']}'),
      'product': product,
      'status': statusKey == null ? '' : tr('customerStatus.${_legacy[statusKey] ?? statusKey}'),
      'id': params['displayId'] == null ? '' : formatRequestId(params['displayId'].toString()),
    }, def: asString(n['message']));
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.notifications')), actions: [
        IconButton(
          tooltip: context.tr('mobile.markAllRead'),
          icon: const Icon(Icons.done_all),
          onPressed: items.any((n) => n['isRead'] != true)
              ? () async {
                  await _api.patch('/api/customer/notifications/read-all');
                  await _load();
                  widget.onChanged();
                }
              : null,
        ),
      ]),
      body: loading
          ? const LoadingView()
          : error != null
              ? ErrorView(error: error!, onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: [SizedBox(height: 320, child: EmptyView(title: context.tr('notifications.empty', def: context.tr('alerts.empty')), icon: Icons.notifications_none))])
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (_, i) {
                            final n = items[i];
                            final unread = n['isRead'] != true;
                            return Card(
                              color: unread ? Brand.purpleTint : Brand.surface,
                              child: ListTile(
                                title: Text(_text(n), style: TextStyle(fontWeight: unread ? FontWeight.w800 : FontWeight.w600)),
                                subtitle: Text(formatStamp(asDate(n['createdAt']))),
                                onTap: () async {
                                  if (unread) {
                                    await _api.patch('/api/customer/notifications/${n['id']}/read');
                                    widget.onChanged();
                                  }
                                  final requestId = n['serviceRequestId']?.toString();
                                  if (requestId != null && context.mounted) {
                                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RequestDetailScreen(requestId: requestId)));
                                  }
                                  _load();
                                },
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}
