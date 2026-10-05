import 'i18n.dart';
import 'models.dart';

// Mirrors server/src/lib/status.ts and client/src/lib/status.ts.

const allStatuses = [
  'new', 'diagnosing', 'awaiting_decision', 'awaiting_parts', 'in_progress', 'paused', 'ready', 'completed',
  'picked_up', 'replaced', 'refunded', 'rejected', 'cancelled',
];

const boardColumns = <String, List<String>>{
  'installation': ['new', 'in_progress', 'paused', 'completed'],
  'repair': ['new', 'diagnosing', 'awaiting_decision', 'awaiting_parts', 'in_progress', 'paused', 'ready', 'picked_up', 'replaced', 'refunded', 'rejected'],
  'all': ['new', 'diagnosing', 'awaiting_decision', 'awaiting_parts', 'in_progress', 'paused', 'ready', 'completed', 'picked_up', 'replaced', 'refunded', 'rejected'],
};

String statusLabel(String status) => tr('status.$status', def: status.replaceAll('_', ' '));

/// Friendly wording for customers.
String customerStatusLabel(String status) => tr('customerStatus.$status', def: statusLabel(status));

/// The work produced a result.
bool isDoneStatus(String status) => status == 'ready' || status == 'completed' || status == 'picked_up' || status == 'replaced';

/// Finished or closed: no more work and no timer.
bool isTerminalStatus(String status) => isDoneStatus(status) || status == 'refunded' || status == 'rejected' || status == 'cancelled';

const techColumns = ['new', 'in_progress', 'paused', 'completed'];

String techColumnOf(String status) {
  if (isTerminalStatus(status)) return 'completed';
  if (status == 'paused' || status == 'awaiting_decision' || status == 'awaiting_parts') return 'paused';
  if (status == 'in_progress' || status == 'diagnosing') return 'in_progress';
  return 'new';
}

typedef _Table = Map<String, List<String>>;

const _repairOffice = <String, List<String>>{
  'new': ['diagnosing', 'in_progress', 'awaiting_decision', 'paused', 'rejected', 'cancelled'],
  'diagnosing': ['awaiting_decision', 'awaiting_parts', 'in_progress', 'paused', 'rejected', 'cancelled'],
  'awaiting_decision': ['diagnosing', 'awaiting_parts', 'in_progress', 'replaced', 'refunded', 'rejected', 'cancelled'],
  'awaiting_parts': ['in_progress', 'paused', 'diagnosing', 'cancelled'],
  'in_progress': ['awaiting_parts', 'awaiting_decision', 'paused', 'ready', 'completed', 'replaced', 'cancelled'],
  'paused': ['in_progress', 'diagnosing', 'cancelled'],
  'ready': ['picked_up', 'in_progress'],
  'completed': ['in_progress', 'picked_up'],
  'cancelled': ['new'],
};

const _installOffice = <String, List<String>>{
  'new': ['in_progress', 'paused', 'cancelled'],
  'in_progress': ['paused', 'completed', 'cancelled'],
  'paused': ['in_progress', 'cancelled'],
  'completed': ['in_progress'],
  'cancelled': ['new'],
};

const _repairTech = <String, List<String>>{
  'new': ['diagnosing', 'in_progress', 'paused'],
  'diagnosing': ['awaiting_decision', 'awaiting_parts', 'in_progress', 'paused'],
  'awaiting_parts': ['in_progress', 'paused'],
  'in_progress': ['awaiting_parts', 'awaiting_decision', 'paused', 'ready', 'completed', 'replaced'],
  'paused': ['in_progress', 'diagnosing'],
};

const _installTech = <String, List<String>>{
  'new': ['in_progress', 'paused'],
  'in_progress': ['paused', 'completed'],
  'paused': ['in_progress'],
};

/// What the signed-in role may move a request to (the server enforces the same rules).
List<String> nextStatuses(String role, Job job) {
  final office = role != 'technician';
  final _Table table = job.isRepair ? (office ? _repairOffice : _repairTech) : (office ? _installOffice : _installTech);
  return (table[job.status] ?? const <String>[])
      .where((next) => next != 'picked_up' || (job.locationType == 'in_shop' && job.pickupConfirmedAt == null))
      .toList();
}

/// The status a finished job ends in (same rule as the server's finishedStatusFor).
String finishedStatusFor({required String type, required String locationType, String? resolution}) {
  if (resolution == 'replace') return 'replaced';
  if (type == 'repair' && locationType == 'in_shop') return 'ready';
  return 'completed';
}
