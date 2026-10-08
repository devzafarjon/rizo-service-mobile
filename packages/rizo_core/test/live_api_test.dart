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

    test('visit slots and warranty plans parse', () async {
      final date = DateTime.now().add(const Duration(days: 2));
      final day = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final slots = asList(asMap(await api.get('/api/customer/visit-slots', query: {'date': day}))['slots']).map(VisitSlot.new).toList();
      expect(slots, isNotEmpty);
      final sale = asList(asMap(await api.get('/api/customer/sales'))['sales']).first;
      asList(asMap(await api.get('/api/customer/warranty-plans', query: {'saleId': sale['id']}))['plans']).map(WarrantyPlanInfo.new).toList();
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
