import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../i18n.dart';
import '../theme.dart';
import 'basics.dart';

/// A label above a form control.
class Labeled extends StatelessWidget {
  const Labeled(this.label, {super.key, required this.child, this.hint});
  final String label;
  final String? hint;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(label.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Brand.subtle, letterSpacing: 0.3))),
        child,
        if (hint != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(hint!, style: TextStyle(fontSize: 12, color: Brand.muted))),
      ]),
    );
  }
}

/// A segmented switch between a few options.
class SegmentedChoice<T> extends StatelessWidget {
  const SegmentedChoice({super.key, required this.value, required this.options, required this.onChanged});
  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: Brand.surfaceAlt, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        for (final entry in options.entries)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(entry.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: entry.key == value ? Brand.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: entry.key == value ? [BoxShadow(color: Brand.shadow, blurRadius: 4, offset: Offset(0, 1))] : null,
                ),
                child: Text(entry.value, textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: entry.key == value ? Brand.ink : Brand.muted)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Wraps a button so it shows a spinner and ignores taps while an async action runs.
class BusyButton extends StatefulWidget {
  const BusyButton({super.key, required this.label, required this.onPressed, this.icon, this.outlined = false, this.danger = false, this.enabled = true});
  final String label;
  final Future<void> Function()? onPressed;
  final IconData? icon;
  final bool outlined;
  final bool danger;
  final bool enabled;
  @override
  State<BusyButton> createState() => _BusyButtonState();
}

class _BusyButtonState extends State<BusyButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy || widget.onPressed == null) return;
    setState(() => _busy = true);
    try {
      await widget.onPressed!();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTap = widget.enabled && !_busy ? _run : null;
    final child = _busy
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
        : Row(mainAxisAlignment: MainAxisAlignment.center, mainAxisSize: MainAxisSize.min, children: [
            if (widget.icon != null) ...[Icon(widget.icon, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(widget.label, textAlign: TextAlign.center)),
          ]);
    if (widget.outlined) {
      return OutlinedButton(onPressed: onTap, style: widget.danger ? OutlinedButton.styleFrom(foregroundColor: Brand.red) : null, child: child);
    }
    return FilledButton(onPressed: onTap, style: widget.danger ? FilledButton.styleFrom(backgroundColor: Brand.red) : null, child: child);
  }
}

// ---- signature ---------------------------------------------------------------------------------------------------

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, this.height = 160, this.onChanged});
  final double height;
  final ValueChanged<bool>? onChanged;
  @override
  State<SignaturePad> createState() => SignaturePadState();
}

class SignaturePadState extends State<SignaturePad> {
  final List<List<Offset>> _strokes = [];
  Size _size = Size.zero;

  bool get isEmpty => _strokes.isEmpty;

  void clear() {
    setState(_strokes.clear);
    widget.onChanged?.call(false);
  }

  /// The drawing as a PNG data URL (what the API stores), or null when nothing was drawn.
  Future<String?> toDataUrl() async {
    if (_strokes.isEmpty || _size.isEmpty) return null;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    _SignaturePainter(_strokes).paint(canvas, _size);
    final image = await recorder.endRecording().toImage(_size.width.ceil(), _size.height.ceil());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) return null;
    return 'data:image/png;base64,${base64Encode(Uint8List.view(data.buffer))}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        height: widget.height,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Brand.line)),
        child: LayoutBuilder(builder: (context, constraints) {
          _size = Size(constraints.maxWidth, constraints.maxHeight);
          return GestureDetector(
            onPanStart: (d) {
              setState(() => _strokes.add([d.localPosition]));
              widget.onChanged?.call(true);
            },
            onPanUpdate: (d) => setState(() => _strokes.last.add(d.localPosition)),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CustomPaint(painter: _SignaturePainter(_strokes), size: Size.infinite)),
          );
        }),
      ),
      Align(alignment: Alignment.centerRight, child: TextButton(onPressed: clear, child: Text(context.tr('pickup.clearSignature')))),
    ]);
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1E293B) // the pad is white paper in both modes
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 1.3, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        continue;
      }
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final p in stroke.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

/// "I received my device" with an optional signature. Customers see first-person wording; staff confirm for them.
class PickupConfirmCard extends StatefulWidget {
  const PickupConfirmCard({super.key, required this.onConfirm, this.customer = false});
  final Future<void> Function(String? signature) onConfirm;
  final bool customer;
  @override
  State<PickupConfirmCard> createState() => _PickupConfirmCardState();
}

class _PickupConfirmCardState extends State<PickupConfirmCard> {
  final _pad = GlobalKey<SignaturePadState>();
  String _mode = 'tap';
  bool _hasInk = false;

  String _k(String name) => widget.customer ? 'pickup.customer.$name' : 'pickup.$name';

  @override
  Widget build(BuildContext context) {
    return Section(
      title: context.tr(_k('title')),
      hint: context.tr(_k('hint')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SegmentedChoice<String>(value: _mode, options: {'tap': context.tr(_k('tap')), 'sign': context.tr('pickup.sign')}, onChanged: (v) => setState(() => _mode = v)),
        if (_mode == 'sign') ...[const SizedBox(height: 12), SignaturePad(key: _pad, onChanged: (v) => setState(() => _hasInk = v))],
        const SizedBox(height: 12),
        BusyButton(
          label: context.tr(_k('confirm')),
          icon: Icons.check_circle_outline,
          enabled: _mode == 'tap' || _hasInk,
          onPressed: () async {
            final signature = _mode == 'sign' ? await _pad.currentState?.toDataUrl() : null;
            await widget.onConfirm(signature);
          },
        ),
      ]),
    );
  }
}

// ---- photos ------------------------------------------------------------------------------------------------------

/// Camera and gallery buttons. Pictures are shrunk before they are returned so uploads stay small on mobile data.
class PhotoPickerBar extends StatelessWidget {
  const PhotoPickerBar({super.key, required this.onPicked, this.multiple = true});
  final Future<void> Function(List<Uint8List> photos) onPicked;
  final bool multiple;

  Future<void> _pick(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    try {
      final List<XFile> files;
      if (source == ImageSource.camera || !multiple) {
        final file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600, maxHeight: 1600);
        files = file == null ? [] : [file];
      } else {
        files = await picker.pickMultiImage(imageQuality: 80, maxWidth: 1600, maxHeight: 1600, limit: 8);
      }
      if (files.isEmpty) return;
      await onPicked([for (final f in files) await f.readAsBytes()]);
    } catch (_) {
      if (context.mounted) showSnack(context, context.tr('errors.uploadFailed'), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: Text(context.tr('common.takePhoto')))),
      const SizedBox(width: 10),
      Expanded(child: OutlinedButton.icon(onPressed: () => _pick(context, ImageSource.gallery), icon: const Icon(Icons.add_photo_alternate_outlined), label: Text(context.tr('job.addPhotos')))),
    ]);
  }
}

/// A date and time picker in one step.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final date = await showDatePicker(context: context, initialDate: initial ?? now, firstDate: now.subtract(const Duration(days: 1)), lastDate: now.add(const Duration(days: 365)));
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial ?? now));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

/// Asks a yes/no question.
Future<bool> confirmDialog(BuildContext context, String title, {String? body, String? confirmLabel}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: body == null ? null : Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.tr('common.cancel'))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel ?? ctx.tr('common.done'))),
      ],
    ),
  );
  return result ?? false;
}

/// Asks for one line of text (a reason, a note).
Future<String?> promptDialog(BuildContext context, {required String title, String? label, String? hint, bool required = true, int maxLines = 2, String? initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (hint != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: Text(hint, style: TextStyle(fontSize: 13, color: Brand.muted))),
          TextField(controller: controller, maxLines: maxLines, minLines: 1, autofocus: true, decoration: InputDecoration(labelText: label), onChanged: (_) => setState(() {})),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.tr('common.cancel'))),
          TextButton(onPressed: !required || controller.text.trim().isNotEmpty ? () => Navigator.pop(ctx, controller.text.trim()) : null, child: Text(ctx.tr('common.save'))),
        ],
      );
    }),
  );
}
