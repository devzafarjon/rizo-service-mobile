import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Technician actions shared by the board and the job screen. Every change goes through [TechRepository], which
/// applies it on the device straight away and sends it to the server when there is a connection.
class TechActions {
  TechActions(this.context, this.repo);
  final BuildContext context;
  final TechRepository repo;

  Future<JobWork?> run(Future<JobWork> Function() action) async {
    try {
      return await action();
    } on LocalValidationError catch (error) {
      if (context.mounted) {
        final list = error.missing.map((code) => tr('job.gap.$code')).join(', ');
        showSnack(context, tr('job.stillNeed', params: {'list': list}), error: true);
      }
    } catch (error) {
      if (context.mounted) showSnack(context, Translator.I.errorMessage(error), error: true);
    }
    return null;
  }

  Future<JobWork?> status(Job job, String status) => run(() => repo.perform(job.id, 'move', {'status': status}));

  Future<JobWork?> start(Job job) => status(job, job.isRepair && job.status == 'new' ? 'diagnosing' : 'in_progress');

  Future<JobWork?> arrived(Job job) => run(() => repo.perform(job.id, 'arrived', {}));
  Future<JobWork?> enRoute(Job job) => run(() => repo.perform(job.id, 'enRoute', {}));

  /// Asks for a reason and how long, then pauses (the server requires both).
  Future<JobWork?> pause(Job job) async {
    final result = await showDialog<({String reason, double hours})>(context: context, builder: (_) => PauseDialog(name: job.customer.name));
    if (result == null) return null;
    return run(() => repo.perform(job.id, 'move', {'status': 'paused', 'pauseReason': result.reason, 'pauseHours': result.hours}));
  }

  /// Finishes the job after checking what is still missing.
  Future<JobWork?> complete(Job job) async {
    final ok = await confirmDialog(context, tr('job.completeJob'), body: '${job.customer.name} · ${formatRequestId(job.displayId)}', confirmLabel: tr('tech.complete'));
    if (!ok || !context.mounted) return null;
    final result = await run(() => repo.perform(job.id, 'complete', {}));
    if (result != null && context.mounted) {
      showSnack(context, result.coveredByWarranty ? tr('job.completedCovered') : tr('job.completed'));
    }
    return result;
  }
}

class PauseDialog extends StatefulWidget {
  const PauseDialog({super.key, required this.name});
  final String name;
  @override
  State<PauseDialog> createState() => _PauseDialogState();
}

class _PauseDialogState extends State<PauseDialog> {
  final _reason = TextEditingController();
  double _hours = 2;
  static const _choices = [1.0, 2.0, 4.0, 8.0, 24.0, 48.0];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('tech.pauseTitle')),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(context.tr('tech.pauseHint', params: {'name': widget.name}), style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
          const SizedBox(height: 14),
          TextField(controller: _reason, maxLines: 2, minLines: 1, autofocus: true, onChanged: (_) => setState(() {}), decoration: InputDecoration(labelText: context.tr('tech.pauseReason'), hintText: context.tr('tech.pauseReasonPlaceholder'))),
          const SizedBox(height: 14),
          Text(context.tr('tech.pauseHours'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final h in _choices) ChoiceChip(label: Text(context.tr('tech.hoursShort', params: {'count': h.round()})), selected: _hours == h, onSelected: (_) => setState(() => _hours = h)),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(context.tr('common.cancel'))),
        TextButton(onPressed: _reason.text.trim().isEmpty ? null : () => Navigator.pop(context, (reason: _reason.text.trim(), hours: _hours)), child: Text(context.tr('tech.pauseSubmit'))),
      ],
    );
  }
}
