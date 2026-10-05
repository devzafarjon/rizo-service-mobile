import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

/// Shows when the device is offline or changes are still waiting to be sent.
class SyncBar extends StatelessWidget {
  const SyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TechRepository>();
    final pending = repo.pendingCount;
    if (!repo.offline && pending == 0) return const SizedBox.shrink();
    final offline = repo.offline;
    final text = offline
        ? (pending > 0 ? context.tr('mobile.offlinePending', params: {'count': pending}) : context.tr('mobile.offlineBanner'))
        : context.tr('mobile.syncing', params: {'count': pending});
    return Material(
      color: offline ? Brand.orangeTint : Brand.purpleTint,
      child: InkWell(
        onTap: () => repo.refresh(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          child: Row(children: [
            Icon(offline ? Icons.cloud_off_outlined : Icons.sync, size: 18, color: offline ? Brand.orangeText : Brand.purple),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: offline ? Brand.orangeText : Brand.purple))),
            Text(context.tr('mobile.retry'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: offline ? Brand.orangeText : Brand.purple)),
          ]),
        ),
      ),
    );
  }
}
