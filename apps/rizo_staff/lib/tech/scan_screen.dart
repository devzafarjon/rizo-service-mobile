import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:rizo_core/rizo_core.dart';

/// Reads the QR sticker on a device (or a typed request number) and opens that job.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, required this.resolve});

  /// Looks the scanned number up and returns the screen to open (throws when it cannot be found).
  final Future<Widget> Function(String displayId) resolve;
  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _manual = TextEditingController();
  bool _busy = false;
  bool _cameraOk = true;

  /// `RIZO:<number>`, a link ending in the number, or just the number (same rules as the website).
  static String? parseTag(String raw) {
    final text = raw.trim();
    final tagged = RegExp(r'^RIZO[:/|#-]([A-Za-z0-9]+)$', caseSensitive: false).firstMatch(text);
    if (tagged != null) return normalizeDisplayId(tagged.group(1)!);
    final uri = Uri.tryParse(text);
    if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.lastWhere((s) => s.isNotEmpty, orElse: () => '');
      if (last.isNotEmpty) return normalizeDisplayId(last);
    }
    final digits = normalizeDisplayId(text);
    return digits.length >= 8 ? digits : null;
  }

  Future<void> _open(String raw) async {
    if (_busy) return;
    final id = parseTag(raw);
    if (id == null) {
      showSnack(context, context.tr('tag.invalid'), error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      final page = await widget.resolve(id);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => page));
    } catch (error) {
      if (mounted) showSnack(context, context.errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('nav.scan'))),
      body: Column(children: [
        Expanded(
          child: _cameraOk
              ? MobileScanner(
                  onDetect: (capture) {
                    final value = capture.barcodes.map((b) => b.rawValue).whereType<String>().firstOrNull;
                    if (value != null) _open(value);
                  },
                  errorBuilder: (context, error) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && _cameraOk) setState(() => _cameraOk = false);
                    });
                    return const SizedBox.shrink();
                  },
                )
              : Center(child: Padding(padding: const EdgeInsets.all(32), child: Text(context.tr('mobile.cameraUnavailable'), textAlign: TextAlign.center, style: TextStyle(color: Brand.muted)))),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(child: TextField(controller: _manual, onSubmitted: _open, decoration: InputDecoration(hintText: context.tr('tag.manualPlaceholder')))),
              const SizedBox(width: 10),
              SizedBox(width: 110, child: BusyButton(label: context.tr('tag.open'), onPressed: () => _open(_manual.text))),
            ]),
          ),
        ),
      ]),
    );
  }
}
