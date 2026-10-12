import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../theme.dart';
import 'basics.dart';

/// What the server says about the Telegram bot for the signed-in person.
class TelegramStatus {
  TelegramStatus(Json m)
      : configured = m['configured'] == true,
        linked = m['linked'] == true,
        username = m['username']?.toString(),
        notify = m['notify'] != false;
  final bool configured;
  final bool linked;
  final String? username;

  /// Staff only: alerts also go to Telegram.
  final bool notify;
}

/// Connects the signed-in person to the RIZO Telegram bot with a one-time link, shows whether it is connected, and disconnects.
/// Staff can also mute the alerts Telegram receives. [scope] is `staff` or `customer`.
class TelegramCard extends StatefulWidget {
  const TelegramCard({super.key, required this.api, required this.scope, this.isAdmin = false, this.onChanged});
  final ApiClient api;
  final String scope;
  final bool isAdmin;
  final VoidCallback? onChanged;
  @override
  State<TelegramCard> createState() => _TelegramCardState();
}

class _TelegramCardState extends State<TelegramCard> with WidgetsBindingObserver {
  TelegramStatus? status;
  Object? error;
  bool busy = false;

  String get _base => '/api/${widget.scope}/telegram';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from Telegram: the chat has linked itself by now.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    try {
      final r = asMap(await widget.api.get(_base));
      if (mounted) {
        final before = status?.linked;
        setState(() {
          status = TelegramStatus(r);
          error = null;
        });
        if (before != null && before != status!.linked) widget.onChanged?.call();
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) showSnack(context, context.errorText(e), error: true);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _connect() => _run(() async {
        final r = asMap(await widget.api.post('$_base/link'));
        if (!mounted) return;
        showSnack(context, tr('telegram.opened'));
        await openUri(context, Uri.parse(r['url'].toString()));
      });

  Future<void> _disconnect() => _run(() async {
        final r = asMap(await widget.api.delete(_base));
        if (!mounted) return;
        setState(() => status = TelegramStatus(r));
        showSnack(context, tr('telegram.disconnected'));
        widget.onChanged?.call();
      });

  Future<void> _mute(bool on) => _run(() async {
        final r = asMap(await widget.api.patch(_base, body: {'notify': on}));
        if (mounted) setState(() => status = TelegramStatus(r));
      });

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final s = status;
    final linked = s?.linked ?? false;
    return Section(
      title: context.tr('telegram.title'),
      hint: context.tr(widget.scope == 'staff' ? 'telegram.staffBody' : 'telegram.customerBody'),
      child: error != null && s == null
          ? Text(context.errorText(error!), style: TextStyle(color: Brand.red))
          : s == null
              ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(linked ? Icons.check_circle : Icons.circle_outlined, size: 18, color: linked ? Brand.green : Brand.muted),
                    const SizedBox(width: 8),
                    Text(context.tr(linked ? 'telegram.connected' : 'telegram.notConnected'), style: const TextStyle(fontWeight: FontWeight.w800)),
                  ]),
                  const SizedBox(height: 10),
                  if (!s.configured)
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Brand.amberTint, borderRadius: BorderRadius.circular(12)),
                      child: Text(context.tr(widget.isAdmin ? 'telegram.notSetUpAdmin' : 'telegram.notSetUp'), style: TextStyle(color: Brand.amberText, fontSize: 13)),
                    )
                  else if (linked) ...[
                    if (widget.scope == 'staff') SwitchListTile(contentPadding: EdgeInsets.zero, value: s.notify, onChanged: busy ? null : _mute, title: Text(context.tr('telegram.alertsOn'))),
                    OutlinedButton(onPressed: busy ? null : _disconnect, style: OutlinedButton.styleFrom(foregroundColor: Brand.red), child: Text(context.tr('telegram.disconnect'))),
                  ] else ...[
                    SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: busy ? null : _connect, icon: const Icon(Icons.send), label: Text(context.tr('telegram.connect')))),
                    const SizedBox(height: 6),
                    Text(context.tr('telegram.connectHint'), style: TextStyle(color: Brand.muted, fontSize: 12)),
                  ],
                ]),
    );
  }
}
