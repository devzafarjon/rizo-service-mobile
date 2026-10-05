import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../api.dart';
import '../i18n.dart';
import '../models.dart';
import '../session.dart';
import '../status.dart';
import 'job_patch.dart';
import 'storage.dart';

/// One change made by the technician that has to reach the server.
class OfflineOp {
  OfflineOp({required this.id, required this.kind, required this.jobId, required this.args, required this.createdAt, this.displayId = ''});

  factory OfflineOp.fromJson(Json m) => OfflineOp(
        id: m['id'].toString(),
        kind: m['kind'].toString(),
        jobId: m['jobId'].toString(),
        displayId: m['displayId']?.toString() ?? '',
        args: asMap(m['args']),
        createdAt: DateTime.tryParse(m['createdAt']?.toString() ?? '') ?? DateTime.now(),
      );

  final String id;
  final String kind;
  final String jobId;
  final String displayId;
  final Json args;
  final DateTime createdAt;

  Json toJson() => {'id': id, 'kind': kind, 'jobId': jobId, 'displayId': displayId, 'args': args, 'createdAt': createdAt.toIso8601String()};
}

/// A change the server refused when it was finally sent (for example the job was reassigned meanwhile).
class SyncFailure {
  SyncFailure(this.displayId, this.kind, this.message);
  final String displayId;
  final String kind;
  final String message;
}

class LocalValidationError implements Exception {
  LocalValidationError(this.missing);
  final List<String> missing;
}

/// The technician's data layer: loads jobs from the server, keeps a copy on the device, applies changes right
/// away and sends them when there is a connection (in the order they were made).
class TechRepository extends ChangeNotifier {
  TechRepository(this.session) : _cache = KeyValueCache(session.user?.id ?? 'anon') {
    _init = _load();
  }

  final StaffSession session;
  final KeyValueCache _cache;
  late final Future<void> _init;

  ApiClient get _api => session.api;

  List<Job> jobs = [];
  bool loading = false;
  bool offline = false;
  DateTime? lastSync;
  final List<OfflineOp> _queue = [];
  final List<SyncFailure> failures = [];
  final Map<String, Json> _work = {};
  bool _flushing = false;
  Timer? _timer;
  bool _disposed = false;

  int get pendingCount => _queue.length;
  bool hasPending(String jobId) => _queue.any((op) => op.jobId == jobId);
  Future<void> get ready => _init;

  Future<void> _load() async {
    final board = await _cache.read('board');
    if (board is List) jobs = board.map(Job.fromJson).toList();
    final queue = await _cache.read('queue');
    if (queue is List) _queue.addAll(queue.map((e) => OfflineOp.fromJson(asMap(e))));
    final sync = await _cache.read('lastSync');
    if (sync is String) lastSync = DateTime.tryParse(sync);
    notifyListeners();
  }

  /// Retry from time to time while the app is open.
  void startAutoSync() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 45), (_) => refresh(silent: true));
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _saveQueue() => _cache.write('queue', _queue.map((o) => o.toJson()).toList());
  Future<void> _saveBoard() => _cache.write('board', jobs.map((j) => j.raw).toList());

  // ---- reading ---------------------------------------------------------------------------------------------

  /// Sends waiting changes, then loads the job list.
  Future<void> refresh({bool silent = false}) async {
    await _init;
    if (!silent) {
      loading = true;
      _notify();
    }
    try {
      await flush();
      if (_queue.isEmpty) {
        final data = await _api.get('/api/staff/my-jobs');
        jobs = asList(asMap(data)['jobs']).map(Job.new).toList();
        offline = false;
        lastSync = DateTime.now();
        await _saveBoard();
        await _cache.write('lastSync', lastSync!.toIso8601String());
        unawaited(_prefetch());
      }
    } on ApiException catch (error) {
      if (error.isRetryable) {
        offline = true;
      } else if (!error.isAuth) {
        rethrow;
      }
    } finally {
      loading = false;
      _notify();
    }
  }

  /// Keeps the open jobs available offline.
  Future<void> _prefetch() async {
    for (final job in jobs.where((j) => (j.column ?? techColumnOf(j.status)) != 'completed').take(25)) {
      if (hasPending(job.id)) continue;
      try {
        final data = await _api.get('/api/staff/my-jobs/${job.id}');
        _work[job.id] = asMap(data);
        await _cache.write('job_${job.id}', _work[job.id]);
      } on ApiException catch (error) {
        if (error.isRetryable) return;
      }
    }
    _notify();
  }

  JobWork? cachedWork(String id) => _work[id] == null ? null : JobWork(_work[id]!);

  /// Opens a job: from the server when possible, otherwise the copy on the device.
  Future<JobWork> loadJob(String id) async {
    await _init;
    if (!_work.containsKey(id)) {
      final cached = await _cache.read('job_$id');
      if (cached is Map) _work[id] = asMap(cached);
    }
    if (!hasPending(id)) {
      try {
        final data = await _api.get('/api/staff/my-jobs/$id');
        _work[id] = asMap(data);
        offline = false;
        await _cache.write('job_$id', _work[id]);
        _syncBoardEntry(id);
      } on ApiException catch (error) {
        if (!error.isRetryable || _work[id] == null) rethrow;
        offline = true;
      }
    }
    final work = _work[id];
    if (work == null) throw ApiException(0, 'Not available offline', code: 'network');
    return JobWork(work);
  }

  /// Looks a job up by the number printed on its tag (online only).
  Future<JobWork> lookup(String displayId) async {
    final data = await _api.get('/api/staff/my-jobs/lookup/${Uri.encodeComponent(displayId)}');
    final map = asMap(data);
    final id = asMap(map['job'])['id'].toString();
    _work[id] = map;
    await _cache.write('job_$id', map);
    return JobWork(map);
  }

  void _syncBoardEntry(String id) {
    final work = _work[id];
    if (work == null) return;
    final index = jobs.indexWhere((j) => j.id == id);
    if (index >= 0) {
      jobs[index] = Job(asMap(work['job']));
      _saveBoard();
    }
    _notify();
  }

  // ---- changes ---------------------------------------------------------------------------------------------

  static int _counter = 0;
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}${_counter++}';

  /// Applies the change on the device and queues it for the server. Returns the updated job.
  Future<JobWork> perform(String jobId, String kind, Json args, {Uint8List? photo}) async {
    await _init;
    final base = _work[jobId] ?? asMap(await _cache.read('job_$jobId'));
    if (base.isEmpty) throw ApiException(0, 'Open this job once while online first', code: 'network');
    final payload = JobPatch.clone(base);
    final id = _newId();
    final displayId = asMap(payload['job'])['displayId']?.toString() ?? '';
    var op = OfflineOp(id: id, kind: kind, jobId: jobId, args: Map<String, dynamic>.from(args), createdAt: DateTime.now(), displayId: displayId);
    var enqueue = true;
    final now = DateTime.now();

    switch (kind) {
      case 'move':
        final status = args['status']?.toString() ?? _statusForColumn(asMap(payload['job']), args['column']?.toString());
        JobPatch.move(payload, status: status, pauseReason: args['pauseReason']?.toString(), pauseHours: args['pauseHours'] as num?, now: now);
        op.args['status'] = status;
        op.args.remove('column');
      case 'arrived':
        JobPatch.arrived(payload, now);
      case 'enRoute':
        JobPatch.enRoute(payload, now);
      case 'diagnosis':
        JobPatch.diagnosis(payload, args['defectCodeId']?.toString());
      case 'serviceAdd':
        JobPatch.addService(payload, id, args['serviceCatalogItemId'].toString());
      case 'serviceRemove':
        final lineId = args['lineId'].toString();
        JobPatch.removeService(payload, lineId);
        enqueue = !await _dropLocalOp(lineId);
      case 'partAdd':
        JobPatch.addPart(payload, id, args['sparePartId'].toString(), asInt(args['quantity'], 1));
      case 'partQty':
        final lineId = args['lineId'].toString();
        final qty = asInt(args['quantity']);
        JobPatch.setPartQuantity(payload, lineId, qty);
        if (lineId.startsWith('local-')) {
          enqueue = false;
          await _changeLocalPartOp(lineId, qty);
        }
      case 'extraAdd':
        JobPatch.addExtra(payload, id, args['description'].toString(), asDouble(args['price']));
      case 'extraRemove':
        final extraId = args['expenseId'].toString();
        JobPatch.removeExtra(payload, extraId);
        enqueue = !await _dropLocalOp(extraId);
      case 'estimate':
        JobPatch.estimate(payload, id, lines: (args['lines'] as List).map(asMap).toList(), note: args['note']?.toString(), send: args['send'] == true, byName: session.user?.name);
      case 'partOrder':
        JobPatch.partOrder(payload, id, args['sparePartId'].toString(), asInt(args['quantity'], 1));
      case 'resolution':
        JobPatch.resolution(payload, type: args['resolutionType'].toString(), productId: args['productId']?.toString(), serial: args['serialNumber']?.toString());
      case 'complete':
        JobPatch.recompute(payload);
        final missing = (payload['missing'] as List).map((e) => e.toString()).toList();
        if (missing.isNotEmpty) throw LocalValidationError(missing);
        JobPatch.complete(payload);
      case 'photo':
        if (photo == null) throw ArgumentError('photo bytes are required');
        final ref = await PhotoStore.save(id, photo);
        op.args['ref'] = ref;
        JobPatch.addPhoto(payload, id, ref, session.user?.name ?? '');
      case 'photoRemove':
        final photoId = args['photoId'].toString();
        final removedRef = _localPhotoRef(payload, photoId);
        JobPatch.removePhoto(payload, photoId);
        if (photoId.startsWith('local-')) {
          enqueue = false;
          await _dropLocalOp(photoId);
          if (removedRef != null) await PhotoStore.delete(removedRef);
        }
      default:
        throw ArgumentError('Unknown change: $kind');
    }

    JobPatch.recompute(payload);
    _work[jobId] = payload;
    await _cache.write('job_$jobId', payload);
    _syncBoardEntry(jobId);
    if (enqueue) {
      _queue.add(op);
      await _saveQueue();
    }
    _notify();
    unawaited(flush());
    return JobWork(payload);
  }

  String _statusForColumn(Json job, String? column) {
    if (column == 'paused') return 'paused';
    if (column == 'completed') return 'completed';
    return job['status'] == 'new' && job['type'] == 'repair' ? 'diagnosing' : 'in_progress';
  }

  String? _localPhotoRef(Json payload, String photoId) {
    for (final p in asList(payload['photos'])) {
      if (p['id'] == photoId) {
        final url = p['photoUrl']?.toString() ?? '';
        return url.startsWith('local:') ? url.substring(6) : null;
      }
    }
    return null;
  }

  /// Removes the queued "add" for something that never reached the server. Returns true when found.
  Future<bool> _dropLocalOp(String localId) async {
    if (!localId.startsWith('local-')) return false;
    final opId = localId.substring(6);
    final index = _queue.indexWhere((o) => o.id == opId);
    if (index < 0) return false;
    _queue.removeAt(index);
    await _saveQueue();
    return true;
  }

  Future<void> _changeLocalPartOp(String localId, int quantity) async {
    final opId = localId.substring(6);
    final index = _queue.indexWhere((o) => o.id == opId);
    if (index < 0) return;
    if (quantity <= 0) {
      _queue.removeAt(index);
    } else {
      _queue[index].args['quantity'] = quantity;
    }
    await _saveQueue();
  }

  // ---- sending ---------------------------------------------------------------------------------------------

  Future<Object?> _send(OfflineOp op) async {
    final base = '/api/staff/my-jobs/${op.jobId}';
    final a = op.args;
    switch (op.kind) {
      case 'move':
        return _api.patch(base, body: {
          'status': a['status'],
          if (a['pauseReason'] != null) 'pauseReason': a['pauseReason'],
          if (a['pauseHours'] != null) 'pauseHours': a['pauseHours'],
        });
      case 'arrived':
        return _api.post('$base/arrived');
      case 'enRoute':
        return _api.post('$base/en-route');
      case 'diagnosis':
        return _api.put('$base/diagnosis', body: {'defectCodeId': a['defectCodeId']});
      case 'serviceAdd':
        return _api.post('$base/service-lines', body: {'serviceCatalogItemId': a['serviceCatalogItemId']});
      case 'serviceRemove':
        return _api.delete('$base/service-lines/${a['lineId']}');
      case 'partAdd':
        return _api.post('$base/part-lines', body: {'sparePartId': a['sparePartId'], 'quantity': a['quantity'] ?? 1});
      case 'partQty':
        return _api.patch('$base/part-lines/${a['lineId']}', body: {'quantity': a['quantity']});
      case 'extraAdd':
        return _api.post('$base/extra-expenses', body: {'description': a['description'], 'price': a['price']});
      case 'extraRemove':
        return _api.delete('$base/extra-expenses/${a['expenseId']}');
      case 'estimate':
        return _api.post('$base/estimates', body: {'lines': a['lines'], 'note': a['note'], 'send': a['send'] == true});
      case 'partOrder':
        return _api.post('$base/part-orders', body: {'sparePartId': a['sparePartId'], 'quantity': a['quantity']});
      case 'resolution':
        return _api.put('$base/resolution', body: {
          'resolutionType': a['resolutionType'],
          if (a['productId'] != null) 'productId': a['productId'],
          if (a['serialNumber'] != null) 'serialNumber': a['serialNumber'],
        });
      case 'complete':
        return _api.post('$base/complete');
      case 'photo':
        final bytes = await PhotoStore.read(a['ref'].toString());
        if (bytes == null) return null; // the file is gone; nothing to send
        return _api.upload('$base/photos', [UploadFile('photo-${op.id}.jpg', bytes)]);
      case 'photoRemove':
        return _api.delete('$base/photos/${a['photoId']}');
    }
    return null;
  }

  /// Sends the waiting changes in order. Stops at the first connection problem.
  Future<void> flush() async {
    await _init;
    if (_flushing || _queue.isEmpty) return;
    _flushing = true;
    final touched = <String>{};
    try {
      while (_queue.isNotEmpty) {
        final op = _queue.first;
        try {
          await _send(op);
          touched.add(op.jobId);
          if (op.kind == 'photo') await PhotoStore.delete(op.args['ref'].toString());
          _queue.removeAt(0);
          await _saveQueue();
          offline = false;
        } on ApiException catch (error) {
          if (error.isRetryable) {
            offline = true;
            break;
          }
          if (error.isAuth) break;
          // The server refused this change: tell the technician and carry on with the rest.
          failures.add(SyncFailure(op.displayId, op.kind, Translator.I.errorMessage(error)));
          touched.add(op.jobId);
          if (op.kind == 'photo') await PhotoStore.delete(op.args['ref'].toString());
          _queue.removeAt(0);
          await _saveQueue();
        }
      }
    } finally {
      _flushing = false;
    }
    if (_queue.isEmpty) {
      // Everything is sent: replace the local guesses with the server's figures.
      for (final id in touched) {
        try {
          final data = await _api.get('/api/staff/my-jobs/$id');
          _work[id] = asMap(data);
          await _cache.write('job_$id', _work[id]);
          _syncBoardEntry(id);
        } on ApiException {
          break;
        }
      }
    }
    _notify();
  }

  void clearFailures() {
    failures.clear();
    _notify();
  }

  Future<void> clearLocalData() async {
    _timer?.cancel();
    await _cache.clear();
    for (final op in _queue) {
      if (op.kind == 'photo') await PhotoStore.delete(op.args['ref'].toString());
    }
    _queue.clear();
    _work.clear();
    jobs = [];
  }

  /// Debug helper for tests.
  @visibleForTesting
  String debugQueue() => jsonEncode(_queue.map((o) => o.toJson()).toList());
}
