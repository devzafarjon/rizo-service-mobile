// Contract test of the mobile apps' networking and models against a RUNNING API (the same calls the apps make).
// Skipped unless LIVE_API=1, because it needs a server on http://localhost:4000 with the demo seed:
//   PORT=4000 npm run dev:server   (from rizo-service-full)   then   LIVE_API=1 flutter test test/live_api_test.dart
// It writes data (a photo, a rating), so point it at a scratch database, never production.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rizo_core/rizo_core.dart';

final _live = Platform.environment['LIVE_API'] == '1';

// A 1x1 PNG.
final Uint8List _png = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<ApiClient> _signedIn(String scope, String phone, String password) async {
  String? token;
  final api = ApiClient(tokenProvider: () => token);
  final r = asMap(await api.post('/api/$scope/auth/login', body: {'phone': phone, 'password': password}));
  token = r['token'] as String?;
  expect(token, isNotEmpty, reason: 'login $phone');
  return api;
}

void main() {
  test('the server answers', () async {
    final r = asMap(await ApiClient().get('/api/health'));
    expect(r['ok'], true);
  }, skip: !_live);

  group('technician (RIZO Texnik)', () {
    late ApiClient api;
    setUpAll(() async {
      if (_live) api = await _signedIn('staff', '998900000002', 'tech123');
    });

    test('profile and job list parse into the app models', () async {
      final me = asMap(await api.get('/api/staff/auth/me'));
      expect(StaffUser.fromJson(me['user']).role, 'technician');
      final jobs = asList(asMap(await api.get('/api/staff/my-jobs'))['jobs']).map(Job.new).toList();
      expect(jobs, isNotEmpty);
      expect(jobs.first.displayId, isNotEmpty);
    }, skip: !_live);

    test('job detail, checklist, van stock and earnings parse', () async {
      final jobs = asList(asMap(await api.get('/api/staff/my-jobs'))['jobs']).map(Job.new).toList();
      final open = jobs.firstWhere((job) => job.status != 'completed' && job.status != 'cancelled' && job.status != 'replaced', orElse: () => jobs.first);
      final work = JobWork(asMap(await api.get('/api/staff/my-jobs/${open.id}')));
      expect(work.job.id, open.id);
      expect(work.catalogServices, isNotNull);
      final stock = asMap(await api.get('/api/staff/my-jobs/stock'));
      expect(stock['stock'], isA<List>());
      expect(asMap(await api.get('/api/staff/my-jobs/earnings')), isNotEmpty);
    }, skip: !_live);

    test('a photo uploads (multipart "photos") and appears on the job', () async {
      final jobs = asList(asMap(await api.get('/api/staff/my-jobs'))['jobs']).map(Job.new).toList();
      final open = jobs.firstWhere((job) => const ['new', 'diagnosing', 'in_progress', 'paused', 'awaiting_decision', 'awaiting_parts'].contains(job.status));
      final before = JobWork(asMap(await api.get('/api/staff/my-jobs/${open.id}'))).photos.length;
      final after = JobWork(asMap(await api.upload('/api/staff/my-jobs/${open.id}/photos', [UploadFile('photo-test.jpg', _png)]))).photos.length;
      expect(after, before + 1);
    }, skip: !_live);

    test('registering a push token works', () async {
      // No exception means the server accepted it (the reply has no body).
      await api.post('/api/staff/devices', body: {'token': 'live-test-token-${DateTime.now().millisecondsSinceEpoch}', 'platform': 'android'});
    }, skip: !_live);
  });

  group('office (admin in RIZO Texnik)', () {
    late ApiClient api;
    setUpAll(() async {
      if (_live) api = await _signedIn('staff', '998900000001', 'admin123');
    });

    test('request list and detail (including the new feedback field) parse', () async {
      final list = asList(asMap(await api.get('/api/staff/requests'))['requests']).map(Job.new).toList();
      expect(list.length, greaterThan(5));
      final detail = asMap(await api.get('/api/staff/requests/${list.first.id}'));
      expect(Job(asMap(detail['request'])).id, list.first.id);
      expect(detail.containsKey('feedback'), true);
    }, skip: !_live);

    test('alerts and technician board load', () async {
      expect(asMap(await api.get('/api/staff/alerts')), contains('notifications'));
      expect(asMap(await api.get('/api/staff/technicians')), contains('technicians'));
    }, skip: !_live);

    test('the new feedback report answers for the office and is closed to technicians', () async {
      final report = asMap(await api.get('/api/staff/reports/feedback', query: {'preset': 'all'}));
      expect(asMap(report['summary']), contains('distribution'));
      final tech = await _signedIn('staff', '998900000002', 'tech123');
      await expectLater(tech.get('/api/staff/reports/feedback', query: {'preset': 'all'}), throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)));
    }, skip: !_live);
  });

  group('spare-part control (office and warehouse in RIZO Texnik)', () {
    test('overview, waiting jobs, recommendations, orders and suppliers parse into the app models', () async {
      final api = await _signedIn('staff', '998900000007', 'ware1234');
      final me = StaffUser.fromJson(asMap(await api.get('/api/staff/auth/me'))['user']);
      expect(me.isWarehouse && me.usesApp && me.usesParts && me.editsSuppliers, isTrue);
      final overview = PartsOverview(asMap(asMap(await api.get('/api/staff/part-orders/overview'))['overview']));
      expect(overview.waitingRequests, greaterThanOrEqualTo(0));
      final waiting = asList(asMap(await api.get('/api/staff/part-orders/waiting'))['requests']).map((e) => WaitingRequest(asMap(e))).toList();
      for (final r in waiting) {
        expect(r.displayId, isNotEmpty);
        expect(r.items.every((i) => i.needed >= 0), isTrue);
      }
      final groups = asList(asMap(await api.get('/api/staff/part-orders/recommendations'))['groups']).map((e) => RecommendationGroup(asMap(e))).toList();
      for (final g in groups) {
        expect(g.items.every((i) => i.recommended >= 1 && i.reasons.isNotEmpty), isTrue);
      }
      final orders = asList(asMap(await api.get('/api/staff/part-orders'))['orders']).map((e) => PartOrderRow(asMap(e))).toList();
      expect(orders.every((o) => o.partId.isNotEmpty), isTrue);
      final suppliers = asList(asMap(await api.get('/api/staff/suppliers'))['suppliers']).map((e) => SupplierInfo(asMap(e))).toList();
      expect(suppliers.every((s) => s.name.isNotEmpty), isTrue);
      expect(asList(asMap(await api.get('/api/staff/alerts'))['notifications']), isA<List>());
    }, skip: !_live);

    test('the admin dashboard carries the parts numbers and a technician is closed out', () async {
      final admin = await _signedIn('staff', '998900000001', 'admin123');
      final data = DashboardData(asMap(await admin.get('/api/staff/reports/dashboard', query: {'preset': 'month'})));
      expect(data.parts, isNotNull);
      final tech = await _signedIn('staff', '998900000002', 'tech123');
      await expectLater(tech.get('/api/staff/part-orders/overview'), throwsA(isA<ApiException>()));
    }, skip: !_live);
  });

  group('warehouses (keeper, technician and front desk in RIZO Texnik)', () {
    test('the keeper sees their warehouse: list, stock, restock, history and requests parse into the app models', () async {
      final api = await _signedIn('staff', '998900000007', 'ware1234');
      final mine = asMap(await api.get('/api/staff/warehouses/mine'));
      expect(mine['manages'], true);
      final warehouses = asList(asMap(await api.get('/api/staff/warehouses'))['warehouses']).map((e) => Warehouse(asMap(e))).toList();
      expect(warehouses.any((w) => w.isCentral), isTrue);
      final id = mine['warehouseId'].toString();
      final stock = asList(asMap(await api.get('/api/staff/warehouses/$id/stock', query: {'stocked': '1'}))['items']).map((e) => WarehouseStockItem(asMap(e))).toList();
      expect(stock.every((i) => i.partId.isNotEmpty && i.quantity >= 0), isTrue);
      final restock = asList(asMap(await api.get('/api/staff/warehouses/$id/restock'))['suggestions']).map((e) => RestockSuggestion(asMap(e))).toList();
      for (final r in restock) {
        expect(r.options.where((o) => o.recommended).length, 1);
      }
      final history = asList(asMap(await api.get('/api/staff/warehouses/$id/movements'))['movements']).map((e) => WarehouseMovement(asMap(e))).toList();
      expect(history.every((m) => m.kind.isNotEmpty), isTrue);
      final transfers = asList(asMap(await api.get('/api/staff/transfers', query: {'warehouseId': id, 'direction': 'out', 'status': 'open'}))['transfers']).map((e) => StockTransfer(asMap(e))).toList();
      expect(transfers.every((t) => t.isOpen), isTrue);
    }, skip: !_live);

    test('a technician asks for a part and the sources come ranked; the front desk can ask but not run the warehouse', () async {
      final tech = await _signedIn('staff', '998900000002', 'tech123');
      final parts = asList(asMap(await tech.get('/api/staff/my-jobs/parts'))['parts']).map(asMap).toList();
      expect(parts, isNotEmpty);
      final src = asMap(await tech.get('/api/staff/my-jobs/part-sources', query: {'partId': parts.first['id'].toString(), 'quantity': '1'}));
      final options = asList(src['options']).map((e) => SourceOption(asMap(e))).toList();
      expect(options.where((o) => o.recommended).length, 1);
      expect(options.last.isSupplier, isTrue);
      final mineTransfers = asList(asMap(await tech.get('/api/staff/my-jobs/transfers'))['transfers']).map((e) => StockTransfer(asMap(e))).toList();
      expect(mineTransfers, isA<List<StockTransfer>>());
      final desk = await _signedIn('staff', '998900000005', 'desk123');
      expect((asMap(await desk.get('/api/staff/warehouses/mine')))['manages'], false);
      await expectLater(desk.post('/api/staff/transfers/none/ship'), throwsA(isA<ApiException>()));
      await expectLater(tech.get('/api/staff/warehouses'), throwsA(isA<ApiException>()));
    }, skip: !_live);
  });

  group('telegram (connect from the app)', () {
    test('staff and customers can read the bot status; without a bot the link says so', () async {
      final staff = await _signedIn('staff', '998900000002', 'tech123');
      final status = TelegramStatus(asMap(await staff.get('/api/staff/telegram')));
      expect(status.linked, isFalse);
      final customer = await _signedIn('customer', '998900000003', 'customer123');
      final cs = TelegramStatus(asMap(await customer.get('/api/customer/telegram')));
      expect(cs.linked, isFalse);
      if (status.configured) {
        final link = asMap(await staff.post('/api/staff/telegram/link'));
        expect(link['url'].toString(), startsWith('https://t.me/'));
      } else {
        await expectLater(staff.post('/api/staff/telegram/link'), throwsA(isA<ApiException>()));
      }
    }, skip: !_live);
  });

  group('customer (RIZO Mijoz)', () {
    late ApiClient api;
    setUpAll(() async {
      if (_live) api = await _signedIn('customer', '998900000003', 'customer123');
    });

    test('profile, requests, products and help parse', () async {
      final me = asMap(await api.get('/api/customer/auth/me'));
      expect(CustomerUser.fromJson(me['user']).id, isNotEmpty);
      final requests = asList(asMap(await api.get('/api/customer/requests'))['requests']).map(Job.new).toList();
      expect(requests, isNotEmpty);
      expect(asList(asMap(await api.get('/api/customer/sales'))['sales']), isNotEmpty);
      asList(asMap(await api.get('/api/customer/help'))['articles']).map(HelpArticleInfo.new).toList();
      asList(asMap(await api.get('/api/public/centers'))['centers']);
    }, skip: !_live);

    test('visit slots parse', () async {
      final date = DateTime.now().add(const Duration(days: 2));
      final day = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final slots = asList(asMap(await api.get('/api/customer/visit-slots', query: {'date': day}))['slots']).map(VisitSlot.new).toList();
      expect(slots, isNotEmpty);
    }, skip: !_live);

    test('a finished job can be rated and the rating shows on the request', () async {
      final requests = asList(asMap(await api.get('/api/customer/requests'))['requests']);
      final done = requests.where((r) => r['canFeedback'] == true).toList();
      if (done.isEmpty) return; // every finished job already has a rating in this database
      final id = done.first['id'];
      final r = asMap(await api.post('/api/customer/requests/$id/feedback', body: {'rating': 4, 'comment': 'live test', 'tags': ['fast']}));
      expect(asMap(asMap(r['request'])['feedback'])['rating'], 4);
    }, skip: !_live);

    test('the customer cannot read the staff reports', () async {
      await expectLater(api.get('/api/staff/reports/feedback'), throwsA(isA<ApiException>().having((e) => e.status, 'status', anyOf(401, 403))));
    }, skip: !_live);
  });

  test('a bad request is an ApiException with a code, not a crash', () async {
    final api = ApiClient();
    await expectLater(api.post('/api/staff/auth/login', body: {'phone': '1', 'password': 'x'}), throwsA(isA<ApiException>()));
  }, skip: !_live);
}
