import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'actions.dart';

/// One job on the technician's board, with the buttons that fit its current status.
class JobCard extends StatelessWidget {
  const JobCard({super.key, required this.job, required this.actions, required this.onOpen, this.pending = false});
  final Job job;
  final TechActions actions;
  final VoidCallback onOpen;

  /// Changes for this job are still waiting to be sent.
  final bool pending;

  String get _column => job.column ?? techColumnOf(job.status);

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<Translator>().locale;
    final location = job.customerLocation;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(job.customer.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900), maxLines: 2, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Icon(job.isOnSite ? Icons.place : Icons.storefront, size: 20, color: job.isOnSite ? Brand.orange : Brand.purple),
              if (pending) Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.cloud_upload_outlined, size: 18, color: Brand.orangeText)),
            ]),
            const SizedBox(height: 2),
            Text(job.product.name(locale), style: TextStyle(color: Brand.muted, fontSize: 13)),
            Text(formatRequestId(job.displayId), style: TextStyle(color: Brand.faint, fontSize: 12, fontWeight: FontWeight.w700)),
            PhoneLink(job.customer.phone),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 6, children: [
              TypeChip(job.type),
              StatusChip(job.status),
              if (job.isRepeat) Pill(context.tr('detail.repeat'), color: Brand.red, background: Brand.redTint),
              if (job.warrantyStatus == 'in_warranty') WarrantyChip(job.warrantyStatus),
            ]),
            if (job.scheduledAt != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('tech.scheduledFor', params: {'time': formatStamp(job.scheduledAt)}), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w800, fontSize: 12))),
            if (job.timer != null) Padding(padding: const EdgeInsets.only(top: 10), child: CountdownChip(job.timer!)),
            if (job.activePause != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('tech.pausedReason', params: {'reason': job.activePause!.reason}), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Brand.subtle))),
            if (job.isOnSite && location != null)
              Padding(padding: const EdgeInsets.only(top: 10), child: _Wide(label: context.tr('maps.directions'), icon: Icons.navigation_outlined, tone: _Tone.orange, onTap: () => openUri(context, location.mapsUri))),
            if (job.isOnSite && _column != 'completed') ..._siteButtons(context),
            if (_column != 'completed') _Actions(job: job, actions: actions, onOpen: onOpen) else _OpenLink(onOpen: onOpen),
          ]),
        ),
      ),
    );
  }

  List<Widget> _siteButtons(BuildContext context) {
    final widgets = <Widget>[];
    if (job.arrivedAt == null) {
      if (job.enRouteAt != null) {
        widgets.add(Padding(padding: const EdgeInsets.only(top: 8), child: Text(context.tr('tech.enRouteSince', params: {'time': formatStamp(job.enRouteAt)}), style: TextStyle(color: Brand.orangeText, fontWeight: FontWeight.w800, fontSize: 12))));
      } else {
        widgets.add(Padding(padding: const EdgeInsets.only(top: 8), child: _Wide(label: context.tr('tech.enRoute'), icon: Icons.local_shipping_outlined, tone: _Tone.orange, onTap: () => actions.enRoute(job))));
      }
      widgets.add(Padding(padding: const EdgeInsets.only(top: 8), child: _Wide(label: context.tr('tech.arrived'), icon: Icons.done_all, tone: _Tone.neutral, onTap: () => actions.arrived(job))));
    } else {
      widgets.add(Padding(padding: const EdgeInsets.only(top: 8), child: Row(children: [Icon(Icons.done_all, size: 16, color: Brand.green), const SizedBox(width: 6), Text(context.tr('tech.arrivedAt', params: {'time': formatStamp(job.arrivedAt)}), style: TextStyle(color: Brand.green, fontWeight: FontWeight.w800, fontSize: 12))])));
    }
    return widgets;
  }
}

enum _Tone { primary, neutral, orange }

class _Wide extends StatelessWidget {
  const _Wide({required this.label, required this.onTap, this.icon, this.tone = _Tone.neutral});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final _Tone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      _Tone.primary => (Brand.purple, Colors.white),
      _Tone.orange => (Brand.orangeTint, Brand.orangeText),
      _Tone.neutral => (Brand.surfaceAlt, Brand.ink),
    };
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 6)],
              Flexible(child: Text(label, textAlign: TextAlign.center, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 14))),
            ]),
          ),
        ),
      ),
    );
  }
}

class _OpenLink extends StatelessWidget {
  const _OpenLink({required this.onOpen});
  final VoidCallback onOpen;
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(top: 6), child: Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onOpen, child: Text(context.tr('tech.openJob')))));
}

class _Actions extends StatelessWidget {
  const _Actions({required this.job, required this.actions, required this.onOpen});
  final Job job;
  final TechActions actions;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final repair = job.isRepair;
    final buttons = <Widget>[];
    Widget gap(Widget w) => Padding(padding: const EdgeInsets.only(top: 8), child: w);

    if (job.status == 'new') {
      buttons.add(gap(_Wide(label: repair ? context.tr('tech.startDiagnosis') : context.tr('tech.start'), icon: Icons.play_arrow_rounded, tone: _Tone.primary, onTap: () => actions.start(job))));
    }
    if (job.status == 'diagnosing') {
      buttons
        ..add(gap(_Wide(label: context.tr('tech.estimateAction'), icon: Icons.request_quote_outlined, tone: _Tone.primary, onTap: onOpen)))
        ..add(gap(_Wide(label: context.tr('tech.startRepair'), icon: Icons.play_arrow_rounded, onTap: () => actions.status(job, 'in_progress'))))
        ..add(gap(_Wide(label: context.tr('tech.needParts'), icon: Icons.inventory_2_outlined, onTap: onOpen)));
    }
    if (job.status == 'awaiting_decision') {
      buttons.add(gap(Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: Brand.amberTint, borderRadius: BorderRadius.circular(12)),
        child: Text(context.tr('tech.waitingDecision'), textAlign: TextAlign.center, style: TextStyle(color: Brand.amberText, fontWeight: FontWeight.w800, fontSize: 13)),
      )));
    }
    if (job.status == 'awaiting_parts') {
      buttons.add(gap(_Wide(label: context.tr('tech.partsArrived'), icon: Icons.play_arrow_rounded, tone: _Tone.primary, onTap: () => actions.status(job, 'in_progress'))));
    }
    if (job.status == 'paused') {
      buttons.add(gap(_Wide(label: context.tr('tech.resume'), icon: Icons.play_arrow_rounded, tone: _Tone.primary, onTap: () => actions.status(job, 'in_progress'))));
    }
    if (job.status == 'in_progress') {
      if (repair) buttons.add(gap(_Wide(label: context.tr('tech.needParts'), icon: Icons.inventory_2_outlined, onTap: onOpen)));
      buttons.add(gap(_Wide(label: context.tr('tech.complete'), icon: Icons.check_circle_outline, tone: _Tone.primary, onTap: () => _complete(context))));
    }
    if (job.status != 'paused' && job.status != 'awaiting_decision') {
      buttons.add(gap(_Wide(label: context.tr('tech.pause'), icon: Icons.pause_rounded, onTap: () => actions.pause(job))));
    }
    buttons.add(Align(alignment: Alignment.centerRight, child: TextButton(onPressed: onOpen, child: Text(context.tr('tech.openJob')))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: buttons);
  }

  /// Completing needs photos and services, so check the saved copy first and open the job when something is missing.
  Future<void> _complete(BuildContext context) async {
    final cached = actions.repo.cachedWork(job.id);
    if (cached == null || !cached.canComplete) {
      if (cached != null) {
        final list = cached.missing.map((code) => tr('job.gap.$code')).join(', ');
        showSnack(context, tr('job.stillNeed', params: {'list': list}), error: true);
      }
      onOpen();
      return;
    }
    await actions.complete(job);
  }
}
