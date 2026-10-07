import 'dart:convert';

import '../models.dart';
import '../status.dart';

/// Changes a cached job payload the way the server would, so the technician sees the result immediately while
/// offline. The numbers are an estimate; the server's own figures replace them as soon as the change is synced.
class JobPatch {
  static Json clone(Json m) => jsonDecode(jsonEncode(m)) as Json;

  static Json _job(Json p) => (p['job'] ??= <String, dynamic>{}) as Json;
  static List<dynamic> _list(Json p, String key) => (p[key] ??= <dynamic>[]) as List<dynamic>;

  /// The catalog entries themselves (not copies), so stock changes stick.
  static List<Json> _catalog(Json p, String key) {
    final catalog = (p['catalog'] ??= <String, dynamic>{}) as Json;
    return ((catalog[key] ??= <dynamic>[]) as List).cast<Json>();
  }

  /// Moves the job to another status (board column moves are translated by the caller).
  static void move(Json p, {required String status, String? pauseReason, num? pauseHours, DateTime? now}) {
    final job = _job(p);
    final at = (now ?? DateTime.now()).toUtc();
    job['status'] = status;
    job['column'] = techColumnOf(status);
    job['statusChangedAt'] = at.toIso8601String();
    if (status == 'paused') {
      final hours = (pauseHours ?? 1).toDouble();
      job['activePause'] = {'id': 'local-pause', 'reason': pauseReason ?? '', 'pausedAt': at.toIso8601String(), 'customTimerHours': hours};
      job['timer'] = {'startsAt': at.toIso8601String(), 'durationMs': (hours * 3600000).round()};
    } else {
      job['activePause'] = null;
      if (status == 'in_progress' || status == 'diagnosing') {
        job['acceptedAt'] ??= at.toIso8601String();
        job['timer'] = {'startsAt': at.toIso8601String(), 'durationMs': 3 * 86400000};
      } else if (isTerminalStatus(status) || status == 'awaiting_decision' || status == 'awaiting_parts') {
        job['timer'] = null;
      }
    }
    if (isDoneStatus(status)) job['completedAt'] ??= at.toIso8601String();
  }

  static void arrived(Json p, DateTime now) => _job(p)['arrivedAt'] = now.toUtc().toIso8601String();
  static void enRoute(Json p, DateTime now, {int? etaMinutes}) {
    final job = _job(p);
    job['enRouteAt'] ??= now.toUtc().toIso8601String();
    if (etaMinutes != null) {
      job['etaMinutes'] = etaMinutes;
      job['etaSetAt'] = now.toUtc().toIso8601String();
    }
  }

  /// Ticks the given steps (the full list of ticked ids) of the diagnosis or completion checklist.
  static void checklist(Json p, String kind, List<String> checked) {
    final list = (p['checklist'] ??= <String, dynamic>{}) as Json;
    final group = (list[kind] ??= <String, dynamic>{'items': <dynamic>[]}) as Json;
    final valid = asList(group['items']).map((i) => i['id'].toString()).toSet();
    group['checked'] = checked.where(valid.contains).toSet().toList();
  }
  static void diagnosis(Json p, String? defectCodeId) => _job(p)['defectCodeId'] = defectCodeId;

  static void addService(Json p, String opId, String serviceId) {
    final lines = _list(p, 'serviceLines');
    if (lines.any((l) => (l as Json)['serviceCatalogItemId'] == serviceId)) return;
    final catalog = _catalog(p, 'services').firstWhere((s) => s['id'] == serviceId, orElse: () => <String, dynamic>{});
    if (catalog.isEmpty) return;
    lines.add({
      'id': 'local-$opId',
      'serviceCatalogItemId': serviceId,
      'name': catalog['name'],
      'nameUz': catalog['nameUz'],
      'nameRu': catalog['nameRu'],
      'nameEn': catalog['nameEn'],
      'priceAtTime': catalog['price'],
    });
  }

  static void removeService(Json p, String lineId) => _list(p, 'serviceLines').removeWhere((l) => (l as Json)['id'] == lineId);

  static void addPart(Json p, String opId, String partId, int quantity) {
    final lines = _list(p, 'partLines');
    final part = _catalog(p, 'parts').firstWhere((s) => s['id'] == partId, orElse: () => <String, dynamic>{});
    if (part.isEmpty) return;
    final existing = lines.cast<Json?>().firstWhere((l) => l!['sparePartId'] == partId, orElse: () => null);
    if (existing != null) {
      setPartQuantity(p, existing['id'].toString(), (existing['quantity'] as num).toInt() + quantity);
      return;
    }
    final price = asDouble(part['price']);
    final fromCarried = _take(part, quantity);
    lines.add({
      'id': 'local-$opId',
      'sparePartId': partId,
      'quantity': quantity,
      'priceAtTime': price,
      'lineTotal': price * quantity,
      'fromCarried': fromCarried,
      'name': part['name'],
      'nameUz': part['nameUz'],
      'nameRu': part['nameRu'],
      'nameEn': part['nameEn'],
    });
  }

  /// A part is taken from what the technician carries first, then from the warehouse. Returns how many came from the van.
  static int _take(Json part, int quantity) {
    if (part.isEmpty) return 0;
    final carried = part['carried'] is num ? (part['carried'] as num).toInt() : 0;
    final fromVan = carried < quantity ? carried : quantity;
    if (fromVan > 0) part['carried'] = carried - fromVan;
    _stock(part, -(quantity - fromVan));
    return fromVan;
  }

  /// Units that came from the van go back to the van, the rest to the warehouse.
  static void _give(Json part, Json line, int quantity) {
    if (part.isEmpty) return;
    final fromCarried = asInt(line['fromCarried']);
    final back = fromCarried < quantity ? fromCarried : quantity;
    if (back > 0) {
      part['carried'] = asInt(part['carried']) + back;
      line['fromCarried'] = fromCarried - back;
    }
    _stock(part, quantity - back);
  }

  static void setPartQuantity(Json p, String lineId, int quantity) {
    final lines = _list(p, 'partLines');
    final index = lines.indexWhere((l) => (l as Json)['id'] == lineId);
    if (index < 0) return;
    final line = lines[index] as Json;
    final old = (line['quantity'] as num).toInt();
    final part = _catalog(p, 'parts').firstWhere((s) => s['id'] == line['sparePartId'], orElse: () => <String, dynamic>{});
    if (quantity <= 0) {
      lines.removeAt(index);
      _give(part, line, old);
      return;
    }
    line['quantity'] = quantity;
    line['lineTotal'] = asDouble(line['priceAtTime']) * quantity;
    if (quantity < old) {
      _give(part, line, old - quantity);
    } else if (quantity > old) {
      line['fromCarried'] = asInt(line['fromCarried']) + _take(part, quantity - old);
    }
  }

  static void _stock(Json part, int delta) {
    if (part.isEmpty || part['stockQuantity'] is! num) return;
    part['stockQuantity'] = ((part['stockQuantity'] as num).toInt() + delta).clamp(0, 1 << 30);
  }

  static void addExtra(Json p, String opId, String description, num price) {
    _list(p, 'extraExpenses').add({'id': 'local-$opId', 'description': description, 'price': price});
  }

  static void removeExtra(Json p, String id) => _list(p, 'extraExpenses').removeWhere((l) => (l as Json)['id'] == id);

  static void addPhoto(Json p, String opId, String localRef, String uploader) {
    _list(p, 'photos').add({'id': 'local-$opId', 'photoUrl': 'local:$localRef', 'uploadedBy': uploader, 'createdAt': DateTime.now().toUtc().toIso8601String()});
  }

  static void removePhoto(Json p, String id) => _list(p, 'photos').removeWhere((l) => (l as Json)['id'] == id);

  static void resolution(Json p, {required String type, String? productId, String? serial}) {
    p['resolutionType'] = type;
    if (type == 'replace' && productId != null && serial != null && serial.isNotEmpty) {
      final product = _catalog(p, 'replacementProducts').firstWhere((x) => x['id'] == productId, orElse: () => <String, dynamic>{});
      p['replacement'] = {'id': 'local-replacement', 'productId': productId, 'serialNumber': serial, 'name': product['name'], 'nameUz': product['nameUz'], 'nameRu': product['nameRu'], 'nameEn': product['nameEn'], 'sku': product['sku']};
    } else if (type != 'replace') {
      p['replacement'] = null;
    }
  }

  static void estimate(Json p, String opId, {required List<Json> lines, String? note, required bool send, String? byName}) {
    final list = _list(p, 'estimates');
    var total = 0.0;
    final mapped = <Json>[];
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      final qty = asInt(l['quantity'], 1);
      final price = asDouble(l['unitPrice']);
      final optional = l['isOptional'] == true;
      if (!optional) total += qty * price;
      mapped.add({
        'id': 'local-$opId-$i',
        'kind': l['kind'],
        'name': l['name'] ?? '',
        'names': null,
        'quantity': qty,
        'unitPrice': price,
        'isOptional': optional,
        'isSelected': !optional,
      });
    }
    list.insert(0, {
      'id': 'local-$opId',
      'status': send ? 'sent' : 'draft',
      'note': note,
      'validUntil': DateTime.now().toUtc().add(const Duration(days: 7)).toIso8601String(),
      'sentAt': send ? DateTime.now().toUtc().toIso8601String() : null,
      'approvedAt': null,
      'approvedBy': null,
      'declinedAt': null,
      'declineReason': null,
      'createdByName': byName,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'total': total,
      'lines': mapped,
    });
    final job = _job(p);
    if (send && const ['new', 'diagnosing'].contains(job['status'])) move(p, status: 'awaiting_decision');
    (job['estimate'] = {'id': 'local-$opId', 'status': send ? 'sent' : 'draft'});
  }

  static void partOrder(Json p, String opId, String partId, int quantity) {
    final part = _catalog(p, 'parts').firstWhere((s) => s['id'] == partId, orElse: () => <String, dynamic>{});
    _list(p, 'partOrders').add({
      'id': 'local-$opId',
      'quantity': quantity,
      'status': 'requested',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'name': part['name'] ?? '',
      'nameUz': part['nameUz'],
      'nameRu': part['nameRu'],
      'nameEn': part['nameEn'],
    });
  }

  static void complete(Json p) {
    final job = _job(p);
    final status = finishedStatusFor(type: job['type']?.toString() ?? 'repair', locationType: job['locationType']?.toString() ?? 'in_shop', resolution: p['resolutionType']?.toString());
    move(p, status: status);
    final cost = asMap(p['cost']);
    job['finalCost'] = cost['chargedTotal'];
  }

  /// Recalculates the cost block and the "still missing" list from the lines.
  static void recompute(Json p) {
    final services = asList(p['serviceLines']);
    final parts = asList(p['partLines']);
    final extras = asList(p['extraExpenses']);
    final cost = asMap(p['cost']);
    final covered = cost['coveredByWarranty'] == true;
    final servicesTotal = services.fold<double>(0, (s, l) => s + asDouble(l['priceAtTime']));
    final partsTotal = parts.fold<double>(0, (s, l) => s + asDouble(l['priceAtTime']) * asInt(l['quantity'], 1));
    final extrasTotal = extras.fold<double>(0, (s, l) => s + asDouble(l['price']));
    final work = servicesTotal + partsTotal + extrasTotal;
    p['cost'] = {
      ...cost,
      'servicesTotal': servicesTotal,
      'partsTotal': partsTotal,
      'extrasTotal': extrasTotal,
      'catalogTotal': servicesTotal + partsTotal,
      'workTotal': work,
      'chargedTotal': covered ? extrasTotal : work,
    };
    final replacing = p['resolutionType'] == 'replace';
    final requireService = asList(asMap(p['catalog'])['services']).isNotEmpty;
    final previous = (p['missing'] is List ? (p['missing'] as List).map((e) => e.toString()).toList() : <String>[]);
    final gaps = <String>[];
    if (!replacing && requireService && services.isEmpty) gaps.add('service');
    if (asList(p['photos']).isEmpty) gaps.add('photo');
    if (replacing && p['replacement'] == null) gaps.add('replacement');
    // Required checklist steps block completing a repair that is not replaced (the server applies the same rule).
    final job = asMap(p['job']);
    if (job['type'] == 'repair' && !replacing) {
      final completion = asMap(asMap(p['checklist'])['completion']);
      final done = (completion['checked'] is List ? (completion['checked'] as List).map((e) => e.toString()).toSet() : <String>{});
      if (asList(completion['items']).any((i) => i['required'] == true && !done.contains(i['id'].toString()))) gaps.add('checklist');
    }
    // Rules only the server can judge (for example an approved estimate for a paid repair) stay as they were.
    if (previous.contains('estimate')) gaps.add('estimate');
    p['missing'] = gaps;
    p['canComplete'] = gaps.isEmpty;
  }

  /// A short list of what must still be added before this job can be completed.
  static List<String> missing(Json p) {
    final copy = clone(p);
    recompute(copy);
    return (copy['missing'] as List).map((e) => e.toString()).toList();
  }
}
