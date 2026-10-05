import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../format.dart';
import '../i18n.dart';
import '../models.dart';
import '../offline/storage.dart';
import '../status.dart';
import '../theme.dart';

// ---- chips -------------------------------------------------------------------------------------------------------

class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.color = Brand.ink, this.background = const Color(0xFFF3F4F6), this.icon});
  final String label;
  final Color color;
  final Color background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Flexible(child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
      ]),
    );
  }
}

({Color fg, Color bg}) statusColors(String status) {
  switch (status) {
    case 'new':
      return (fg: const Color(0xFF1D4ED8), bg: const Color(0xFFEFF6FF));
    case 'diagnosing':
    case 'in_progress':
      return (fg: Brand.purple, bg: Brand.purpleTint);
    case 'awaiting_decision':
    case 'awaiting_parts':
    case 'paused':
      return (fg: Brand.amberText, bg: const Color(0xFFFEF3C7));
    case 'ready':
    case 'completed':
    case 'picked_up':
    case 'replaced':
      return (fg: Brand.green, bg: Brand.greenTint);
    case 'refunded':
      return (fg: const Color(0xFF0F766E), bg: const Color(0xFFF0FDFA));
    case 'rejected':
    case 'cancelled':
      return (fg: Brand.red, bg: Brand.redTint);
    default:
      return (fg: Brand.ink, bg: const Color(0xFFF3F4F6));
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.friendly = false});
  final String status;
  final bool friendly;

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final c = statusColors(status);
    return Pill(friendly ? customerStatusLabel(status) : statusLabel(status), color: c.fg, background: c.bg);
  }
}

class TypeChip extends StatelessWidget {
  const TypeChip(this.type, {super.key});
  final String type;
  @override
  Widget build(BuildContext context) {
    final repair = type == 'repair';
    return Pill(context.tr('type.$type'), color: repair ? Brand.orangeText : Brand.purple, background: repair ? Brand.orangeTint : Brand.purpleTint, icon: repair ? Icons.build_outlined : Icons.handyman_outlined);
  }
}

class LocationChip extends StatelessWidget {
  const LocationChip(this.type, {super.key});
  final String type;
  @override
  Widget build(BuildContext context) {
    final onSite = type == 'on_site';
    return Pill(context.tr('location.$type'), color: onSite ? Brand.orangeText : Brand.purple, background: onSite ? Brand.orangeTint : Brand.purpleTint, icon: onSite ? Icons.place_outlined : Icons.storefront_outlined);
  }
}

class WarrantyChip extends StatelessWidget {
  const WarrantyChip(this.status, {super.key});
  final String status;
  @override
  Widget build(BuildContext context) {
    final ok = status == 'in_warranty';
    final none = status == 'not_applicable';
    return Pill(context.tr('warranty.$status'), color: ok ? Brand.green : (none ? const Color(0xFF4B5563) : Brand.red), background: ok ? Brand.greenTint : (none ? const Color(0xFFF3F4F6) : Brand.redTint));
  }
}

// ---- cards & states ----------------------------------------------------------------------------------------------

class Section extends StatelessWidget {
  const Section({super.key, this.title, this.hint, required this.child, this.trailing, this.padding = const EdgeInsets.all(16)});
  final String? title;
  final String? hint;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (title != null)
            Row(children: [
              Expanded(child: Text(title!.toUpperCase(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF6B7280), letterSpacing: 0.4))),
              ?trailing,
            ]),
          if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          if (title != null || hint != null) const SizedBox(height: 12),
          child,
        ]),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator()));
}

class EmptyView extends StatelessWidget {
  const EmptyView({super.key, required this.title, this.body, this.icon = Icons.inbox_outlined});
  final String title;
  final String? body;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 44, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          if (body != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(body!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF6B7280)))),
        ]),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 44, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(context.errorText(error), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            SizedBox(width: 200, child: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.tr('mobile.retry')))),
          ],
        ]),
      ),
    );
  }
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Brand.red : null));
}

/// A key/value row used in detail cards.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueWidget});
  final String label;
  final String? value;
  final Widget? valueWidget;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 118, child: Text(label, style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13))),
        Expanded(child: valueWidget ?? Text(value ?? '—', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))),
      ]),
    );
  }
}

// ---- links -------------------------------------------------------------------------------------------------------

Future<void> openUri(BuildContext context, Uri uri) async {
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!ok && context.mounted) showSnack(context, uri.toString(), error: true);
}

class PhoneLink extends StatelessWidget {
  const PhoneLink(this.phone, {super.key, this.style});
  final String phone;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => openUri(context, telUri(phone)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.call_outlined, size: 16, color: Brand.purple),
          const SizedBox(width: 4),
          Text(formatPhone(phone), style: style ?? const TextStyle(color: Brand.purple, fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }
}

// ---- timer -------------------------------------------------------------------------------------------------------

/// Counts down (green, then yellow in the last quarter, red when overdue) and updates every second.
class CountdownChip extends StatefulWidget {
  const CountdownChip(this.timer, {super.key, this.compact = false});
  final JobTimer timer;
  final bool compact;
  @override
  State<CountdownChip> createState() => _CountdownChipState();
}

class _CountdownChipState extends State<CountdownChip> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    final t = widget.timer;
    final remaining = t.endsAt.difference(DateTime.now());
    final overdue = remaining.isNegative;
    final ratio = t.durationMs == 0 ? 0 : remaining.inMilliseconds / t.durationMs;
    final (fg, bg) = overdue ? (Brand.red, Brand.redTint) : (ratio <= 0.25 ? (Brand.amberText, Brand.amberTint) : (Brand.green, Brand.greenTint));
    final total = remaining.abs().inSeconds;
    String two(int v) => v.toString().padLeft(2, '0');
    final days = total ~/ 86400;
    final clock = '${days > 0 ? '${days}d ' : ''}${two((total % 86400) ~/ 3600)}:${two((total % 3600) ~/ 60)}:${two(total % 60)}';
    final text = overdue ? tr('timer.overdue', params: {'clock': clock}) : clock;
    return Container(
      width: widget.compact ? null : double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: widget.compact ? 5 : 9),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: fg.withValues(alpha: 0.25))),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: widget.compact ? 12 : 14, fontFeatures: const [FontFeature.tabularFigures()])),
    );
  }
}

// ---- images ------------------------------------------------------------------------------------------------------

/// Shows an uploaded photo, or one that is still waiting on the device to be uploaded.
class JobImage extends StatelessWidget {
  const JobImage(this.url, {super.key, this.height = 120, this.fit = BoxFit.cover});
  final String url;
  final double height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('local:')) {
      return FutureBuilder<Uint8List?>(
        future: PhotoStore.read(url.substring(6)),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          return SizedBox(
            height: height,
            width: double.infinity,
            child: bytes == null ? const ColoredBox(color: Color(0xFFF3F4F6), child: Icon(Icons.image_outlined)) : Image.memory(bytes, fit: fit),
          );
        },
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Image.network(
        AppConfig.url(url),
        fit: fit,
        errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFF3F4F6), child: Icon(Icons.broken_image_outlined)),
        loadingBuilder: (context, child, progress) => progress == null ? child : const ColoredBox(color: Color(0xFFF3F4F6), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
      ),
    );
  }
}

class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.height = 40});
  final double height;
  @override
  Widget build(BuildContext context) => Image.asset('assets/rizo-logo.png', package: 'rizo_core', height: height, errorBuilder: (_, _, _) => Text('RIZO', style: TextStyle(fontSize: height * 0.7, fontWeight: FontWeight.w900, color: Brand.purple)));
}

// ---- language & server -------------------------------------------------------------------------------------------

class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key, this.onChanged});
  final Future<void> Function(String locale)? onChanged;

  @override
  Widget build(BuildContext context) {
    final translator = context.watch<Translator>();
    return PopupMenuButton<String>(
      tooltip: context.tr('common.language'),
      onSelected: (code) => onChanged != null ? onChanged!(code) : translator.setLocale(code),
      itemBuilder: (_) => [
        for (final code in supportedLocales) CheckedPopupMenuItem(value: code, checked: translator.locale == code, child: Text(tr('languages.$code'))),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.language, size: 20, color: Brand.purple),
          const SizedBox(width: 4),
          Text(translator.locale.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w800, color: Brand.ink)),
        ]),
      ),
    );
  }
}

Future<void> showServerDialog(BuildContext context) async {
  final controller = TextEditingController(text: AppConfig.baseUrl);
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.tr('mobile.serverTitle')),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(ctx.tr('mobile.serverHint'), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        TextField(controller: controller, keyboardType: TextInputType.url, autocorrect: false, decoration: const InputDecoration(hintText: 'https://…')),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('common.cancel'))),
        TextButton(
          onPressed: () async {
            await AppConfig.setBaseUrl(controller.text);
            if (ctx.mounted) Navigator.pop(ctx);
          },
          child: Text(ctx.tr('common.save')),
        ),
      ],
    ),
  );
}

/// Small link under login forms that opens the server-address dialog (only in test builds).
class ServerLink extends StatelessWidget {
  const ServerLink({super.key});
  @override
  Widget build(BuildContext context) {
    if (!AppConfig.canChangeServer) return const SizedBox.shrink();
    return TextButton.icon(onPressed: () => showServerDialog(context), icon: const Icon(Icons.dns_outlined, size: 16), label: Text(context.tr('mobile.serverTitle')));
  }
}
