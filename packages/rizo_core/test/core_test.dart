import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Brightness, Colors, ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, int status) => http.Response.bytes(utf8.encode(jsonEncode(body)), status, headers: {'content-type': 'application/json; charset=utf-8'});

Map<String, dynamic> _bundle(String code) {
  final web = jsonDecode(File('assets/locales/$code.json').readAsStringSync()) as Map<String, dynamic>;
  final extra = jsonDecode(File('assets/mobile/$code.json').readAsStringSync()) as Map<String, dynamic>;
  return {...web, ...extra};
}

Map<String, dynamic> _job({String status = 'new', String type = 'repair', String location = 'in_shop'}) => {
      'job': {'id': 'j1', 'displayId': '051026010001', 'type': type, 'status': status, 'locationType': location, 'column': techColumnOf(status), 'customer': {'id': 'c', 'name': 'Ali', 'phone': '998901112233'}, 'product': {'id': 'p', 'name': 'TV', 'sku': 'TV-1', 'category': 'Televisions'}},
      'serviceLines': [],
      'partLines': [],
      'extraExpenses': [],
      'photos': [],
      'estimates': [],
      'partOrders': [],
      'notes': [],
      'timeline': [],
      'defectCodes': [],
      'cost': {'servicesTotal': 0, 'partsTotal': 0, 'extrasTotal': 0, 'catalogTotal': 0, 'workTotal': 0, 'chargedTotal': 0, 'coveredByWarranty': false},
      'canComplete': false,
      'missing': ['service', 'photo'],
      'resolutionType': null,
      'replacement': null,
      'catalog': {
        'services': [
          {'id': 's1', 'name': 'Repair', 'nameUz': 'Ta’mir', 'price': 50000},
        ],
        'parts': [
          {'id': 'pt1', 'name': 'Cable', 'price': 20000, 'stockQuantity': 5},
        ],
        'replacementProducts': [],
      },
      'settings': {'blockZeroStock': true},
    };

/// perform() starts a background send; give it a moment to finish.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

void main() {
  _themeTests();
  _growthTests();
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Translator', () {
    setUp(() => Translator.I.loadForTest({'uz': _bundle('uz'), 'ru': _bundle('ru'), 'en': _bundle('en')}, locale: 'en'));

    test('nested keys and placeholders', () {
      expect(tr('tech.title'), 'My jobs');
      expect(tr('detail.owes', params: {'amount': '5'}), 'Owes 5');
    });

    test('falls back to the key or the default value', () {
      expect(tr('nope.nothing'), 'nope.nothing');
      expect(tr('nope.nothing', def: 'x'), 'x');
    });

    test('flat dotted keys still resolve (audit log style)', () {
      expect(tr('audit.action.request.status'), isNot('audit.action.request.status'));
    });

    test('russian plurals', () {
      Translator.I.loadForTest({'uz': _bundle('uz'), 'ru': _bundle('ru'), 'en': _bundle('en')}, locale: 'ru');
      final one = tr('portal.pendingFeedback', count: 1);
      final few = tr('portal.pendingFeedback', count: 3);
      final many = tr('portal.pendingFeedback', count: 7);
      expect(few, contains('3'));
      expect(many, contains('7'));
      expect(one, isNot(few));
    });

    test('every language has the app-only keys', () {
      for (final code in ['uz', 'ru', 'en']) {
        Translator.I.loadForTest({'uz': _bundle('uz'), 'ru': _bundle('ru'), 'en': _bundle('en')}, locale: code);
        expect(tr('mobile.offlineBanner'), isNot('mobile.offlineBanner'), reason: code);
      }
    });

    test('api errors map to errors.<code>', () {
      expect(Translator.I.errorMessage(ApiException(400, 'x', code: 'unpaidBalance', details: {'balance': 5000})), contains('5000'));
      expect(Translator.I.errorMessage(ApiException(0, 'x', code: 'network')), tr('mobile.offline'));
    });
  });

  group('status rules', () {
    test('technician board columns', () {
      expect(techColumnOf('new'), 'new');
      expect(techColumnOf('diagnosing'), 'in_progress');
      expect(techColumnOf('awaiting_parts'), 'paused');
      expect(techColumnOf('ready'), 'completed');
      expect(techColumnOf('rejected'), 'completed');
    });

    test('who can move what', () {
      final repair = Job.fromJson({'status': 'in_progress', 'type': 'repair', 'locationType': 'in_shop'});
      expect(nextStatuses('technician', repair), containsAll(['awaiting_parts', 'ready', 'paused']));
      expect(nextStatuses('technician', repair), isNot(contains('cancelled')));
      expect(nextStatuses('admin', repair), contains('cancelled'));
      final ready = Job.fromJson({'status': 'ready', 'type': 'repair', 'locationType': 'in_shop'});
      expect(nextStatuses('admin', ready), contains('picked_up'));
      final onSite = Job.fromJson({'status': 'completed', 'type': 'repair', 'locationType': 'on_site'});
      expect(nextStatuses('admin', onSite), isNot(contains('picked_up')));
    });

    test('finished status', () {
      expect(finishedStatusFor(type: 'repair', locationType: 'in_shop'), 'ready');
      expect(finishedStatusFor(type: 'repair', locationType: 'on_site'), 'completed');
      expect(finishedStatusFor(type: 'installation', locationType: 'on_site'), 'completed');
      expect(finishedStatusFor(type: 'repair', locationType: 'in_shop', resolution: 'replace'), 'replaced');
    });
  });

  group('JobPatch (offline changes)', () {
    test('services, photos and cost', () {
      final p = JobPatch.clone(_job());
      JobPatch.addService(p, 'a', 's1');
      JobPatch.addPhoto(p, 'b', 'mem:b', 'Tech');
      JobPatch.recompute(p);
      expect(asList(p['serviceLines']).single['priceAtTime'], 50000);
      expect(p['cost']['chargedTotal'], 50000);
      expect(p['canComplete'], true);
      expect(p['missing'], isEmpty);
    });

    test('parts use stock and quantity changes give it back', () {
      final p = JobPatch.clone(_job());
      JobPatch.addPart(p, 'a', 'pt1', 2);
      expect(asList(asMap(p['catalog'])['parts']).single['stockQuantity'], 3);
      JobPatch.setPartQuantity(p, 'local-a', 1);
      expect(asList(asMap(p['catalog'])['parts']).single['stockQuantity'], 4);
      JobPatch.setPartQuantity(p, 'local-a', 0);
      expect(asList(p['partLines']), isEmpty);
      expect(asList(asMap(p['catalog'])['parts']).single['stockQuantity'], 5);
    });

    test('warranty covered work only charges extras', () {
      final p = JobPatch.clone(_job());
      p['cost'] = {...asMap(p['cost']), 'coveredByWarranty': true};
      JobPatch.addService(p, 'a', 's1');
      JobPatch.addExtra(p, 'e', 'Delivery', 10000);
      JobPatch.recompute(p);
      expect(p['cost']['chargedTotal'], 10000);
      expect(p['cost']['workTotal'], 60000);
    });

    test('pause, completion and replacement', () {
      final p = JobPatch.clone(_job(status: 'in_progress'));
      JobPatch.move(p, status: 'paused', pauseReason: 'part', pauseHours: 4);
      expect(p['job']['column'], 'paused');
      expect(p['job']['activePause']['reason'], 'part');
      JobPatch.move(p, status: 'in_progress');
      expect(p['job']['activePause'], isNull);
      JobPatch.resolution(p, type: 'replace');
      JobPatch.recompute(p);
      expect(p['missing'], contains('replacement'));
      expect(p['missing'], isNot(contains('service')));
      JobPatch.complete(p);
      expect(p['job']['status'], 'replaced');
    });

    test('estimate sent moves a new repair to awaiting decision', () {
      final p = JobPatch.clone(_job(status: 'diagnosing'));
      JobPatch.estimate(p, 'x', lines: [
        {'kind': 'labor', 'name': 'Work', 'quantity': 1, 'unitPrice': 100000, 'isOptional': false},
        {'kind': 'labor', 'name': 'Extra', 'quantity': 1, 'unitPrice': 30000, 'isOptional': true},
      ], send: true);
      expect(p['job']['status'], 'awaiting_decision');
      expect(asList(p['estimates']).single['total'], 100000);
    });
  });

  group('TechRepository offline queue', () {
    late List<String> calls;
    late bool online;

    StaffSession session() {
      final client = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (!online) throw http.ClientException('offline');
        if (request.url.path.endsWith('/my-jobs')) return _json({'jobs': [(_job())['job']]}, 200);
        if (request.url.path.endsWith('/my-jobs/j1')) {
          final job = _job(status: calls.any((c) => c.startsWith('PATCH')) ? 'in_progress' : 'new');
          return _json(job, 200);
        }
        return _json(_job(status: 'in_progress'), 200);
      });
      final s = StaffSession(httpClient: client);
      s.user = StaffUser(id: 'u1', name: 'Tech', phone: '998900000002', role: 'technician');
      s.token = 't';
      return s;
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      Translator.I.loadForTest({'uz': _bundle('uz'), 'ru': _bundle('ru'), 'en': _bundle('en')}, locale: 'en');
      calls = [];
      online = true;
    });

    test('changes made offline are kept and sent when the connection returns', () async {
      final repo = TechRepository(session());
      await repo.ready;
      await repo.refresh();
      expect(repo.jobs, hasLength(1));
      await repo.loadJob('j1');

      online = false;
      final work = await repo.perform('j1', 'move', {'status': 'in_progress'});
      expect(work.job.status, 'in_progress');
      expect(repo.pendingCount, 1);
      await settle();
      await repo.flush();
      expect(repo.offline, true);
      expect(repo.pendingCount, 1);

      online = true;
      await repo.refresh();
      expect(repo.pendingCount, 0);
      expect(repo.offline, false);
      expect(calls.where((c) => c.startsWith('PATCH')), hasLength(greaterThanOrEqualTo(2)));
      repo.dispose();
    });

    test('adding and removing the same offline service cancels out', () async {
      final repo = TechRepository(session());
      await repo.ready;
      await repo.refresh();
      await repo.loadJob('j1');
      online = false;
      await repo.perform('j1', 'serviceAdd', {'serviceCatalogItemId': 's1'});
      expect(repo.pendingCount, 1);
      final lineId = repo.cachedWork('j1')!.serviceLines.single['id'];
      await repo.perform('j1', 'serviceRemove', {'lineId': lineId});
      expect(repo.pendingCount, 0);
      expect(repo.cachedWork('j1')!.serviceLines, isEmpty);
      repo.dispose();
    });

    test('completing without photos is refused on the device', () async {
      final repo = TechRepository(session());
      await repo.ready;
      await repo.refresh();
      await repo.loadJob('j1');
      expect(() => repo.perform('j1', 'complete', {}), throwsA(isA<LocalValidationError>()));
      repo.dispose();
    });

    test('a refused change is reported, not retried forever', () async {
      final client = MockClient((request) async {
        if (request.url.path.endsWith('/my-jobs/j1') && request.method == 'GET') return _json(_job(), 200);
        if (request.url.path.endsWith('/my-jobs')) return _json({'jobs': []}, 200);
        return _json({'error': 'Pause duration must be greater than 0', 'code': 'invalidInput'}, 400);
      });
      final s = StaffSession(httpClient: client)
        ..user = StaffUser(id: 'u2', name: 'T', phone: '1', role: 'technician')
        ..token = 't';
      final repo = TechRepository(s);
      await repo.ready;
      await repo.loadJob('j1');
      await repo.perform('j1', 'move', {'status': 'paused', 'pauseReason': 'x', 'pauseHours': 1});
      await settle();
      expect(repo.pendingCount, 0);
      expect(repo.failures, hasLength(1));
      repo.dispose();
    });
  });

  group('formatting', () {
    setUp(() => Translator.I.loadForTest({'uz': _bundle('uz'), 'ru': _bundle('ru'), 'en': _bundle('en')}, locale: 'uz'));

    test('phone, request id and money', () {
      expect(formatPhone('998901234567'), '+998 90 123 45 67');
      expect(formatRequestId('051026010001'), '#051026010001');
      expect(formatRequestId('#0510'), '#0510');
      expect(formatMoney(280000), contains('280'));
    });

    test('uzbek dates', () {
      expect(formatDate('2026-10-05'), '05-okt 2026');
    });
  });
}

void _themeTests() {
  group('theme mode', () {
    tearDown(() => Brand.dark = false);

    test('remembers the choice and switches the brand palette', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({'rizo_theme': 'dark'});
      await ThemeController.I.load();
      expect(ThemeController.I.mode, ThemeMode.dark);
      expect(Brand.dark, isTrue);
      final dark = Brand.surface;

      await ThemeController.I.setMode(ThemeMode.light);
      expect(Brand.dark, isFalse);
      expect(Brand.surface, isNot(dark));
      expect((await SharedPreferences.getInstance()).getString('rizo_theme'), 'light');

      await ThemeController.I.setMode(ThemeMode.system);
      expect((await SharedPreferences.getInstance()).getString('rizo_theme'), isNull);
    });

    test('dark theme data uses dark surfaces and keeps white text on purple buttons', () {
      final dark = buildTheme(dark: true);
      expect(dark.brightness, Brightness.dark);
      expect(dark.cardTheme.color, isNot(Colors.white));
      expect(dark.scaffoldBackgroundColor.computeLuminance(), lessThan(0.05));
      expect(buildTheme().brightness, Brightness.light);
    });
  });
}

void _growthTests() {
  group('offline job changes', () {
    Json job() => {
          'job': {'id': 'j1', 'type': 'repair', 'status': 'in_progress', 'locationType': 'on_site'},
          'serviceLines': [
            {'id': 's1', 'serviceCatalogItemId': 'svc', 'priceAtTime': 1000}
          ],
          'partLines': [],
          'extraExpenses': [],
          'photos': [
            {'id': 'p1'}
          ],
          'cost': {'coveredByWarranty': false},
          'catalog': {
            'services': [
              {'id': 'svc', 'price': 1000}
            ],
            'parts': [
              {'id': 'part', 'name': 'Filter', 'price': 500, 'stockQuantity': 5, 'carried': 2}
            ],
          },
          'checklist': {
            'completion': {
              'items': [
                {'id': 'tested', 'uz': 'a', 'ru': 'a', 'en': 'a', 'required': true},
                {'id': 'clean', 'uz': 'b', 'ru': 'b', 'en': 'b', 'required': false},
              ],
              'checked': <String>[],
            },
          },
        };

    test('a required checklist step blocks completing a repair until it is ticked', () {
      final p = JobPatch.clone(job());
      JobPatch.recompute(p);
      expect(p['missing'], contains('checklist'));
      expect(p['canComplete'], isFalse);
      JobPatch.checklist(p, 'completion', ['tested', 'unknown']);
      JobPatch.recompute(p);
      expect(p['missing'], isNot(contains('checklist')));
      expect(p['canComplete'], isTrue);
      expect(JobChecklist(asMap(p['checklist'])).completionChecked, {'tested'});
    });

    test('parts come from the van first and go back to the van when the line shrinks', () {
      final p = JobPatch.clone(job());
      JobPatch.addPart(p, 'op1', 'part', 3);
      // asList copies the maps, so read the live catalog entry.
      final part = ((p['catalog'] as Map)['parts'] as List).first as Map;
      expect(part['carried'], 0);
      expect(part['stockQuantity'], 4); // 2 from the van, 1 from the warehouse
      final line = asList(p['partLines']).first;
      JobPatch.setPartQuantity(p, line['id'].toString(), 1);
      expect(part['carried'], 2); // the two taken from the van are back with the technician
      expect(part['stockQuantity'], 4);
    });

    test('"on my way" keeps the estimate', () {
      final p = JobPatch.clone(job());
      JobPatch.enRoute(p, DateTime.utc(2026, 10, 7, 9), etaMinutes: 25);
      final j = Job(asMap(p['job']));
      expect(j.etaMinutes, 25);
      expect(j.enRouteAt, isNotNull);
    });
  });

  test('portal request exposes the visit and arrival estimate', () {
    final r = PortalRequest({
      'id': 'r',
      'visit': {'slot': '10:00-12:00', 'confirmed': true, 'canBook': true, 'canReschedule': false, 'canCancel': false},
      'eta': {'minutes': 20, 'setAt': '2026-10-07T09:00:00Z'},
    });
    expect(r.visit.slot, '10:00-12:00');
    expect(r.visit.confirmed, isTrue);
    expect(r.visit.canReschedule, isFalse);
    expect(r.etaMinutes, 20);
  });

  test('only technicians, the front desk and admins use the app', () {
    StaffUser user(String role) => StaffUser.fromJson({'id': '1', 'name': 'x', 'phone': '1', 'role': role});
    expect(user('technician').usesApp, isTrue);
    expect(user('admin').usesApp, isTrue);
    expect(user('receptionist').usesApp, isTrue);
    expect(user('accountant').usesApp, isFalse);
    expect(user('warehouse').usesApp, isFalse);
  });
}
