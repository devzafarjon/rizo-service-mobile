import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:rizo_staff/directory/device_picker.dart';
import 'package:rizo_staff/directory/directory_screen.dart';
import 'package:rizo_staff/directory/skills_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A tiny in-memory copy of the directory API, so the screens run for real without a server.
class _FakeDirectory {
  final List<String> calls = [];
  final List<Map<String, dynamic>> brands = [
    {'id': 'own', 'name': 'RIZO', 'isOwn': true, 'approved': true, 'addedByName': null, 'modelCount': 3, 'pendingModels': 0, 'categories': ['Muzlatkichlar']},
    {'id': 'sam', 'name': 'Samsung', 'isOwn': false, 'approved': true, 'addedByName': 'Admin', 'modelCount': 2, 'pendingModels': 1, 'categories': ['Kir yuvish mashinalari']},
    {'id': 'mid', 'name': 'Midea', 'isOwn': false, 'approved': false, 'addedByName': 'Aziz', 'modelCount': 1, 'pendingModels': 1, 'categories': ['Muzlatkichlar']},
  ];
  final List<Map<String, dynamic>> models = [
    {'id': 'm1', 'name': 'Samsung WW70', 'sku': 'EXT-1', 'category': 'Kir yuvish mashinalari', 'brandId': 'sam', 'brandName': 'Samsung', 'isOwn': false, 'approved': true, 'addedByName': 'Admin', 'requestsCount': 2},
    {'id': 'm2', 'name': 'Samsung RB37', 'sku': 'EXT-2', 'category': 'Kir yuvish mashinalari', 'brandId': 'sam', 'brandName': 'Samsung', 'isOwn': false, 'approved': false, 'addedByName': 'Aziz', 'requestsCount': 0},
    {'id': 'm3', 'name': 'Midea MDRB', 'sku': 'EXT-3', 'category': 'Muzlatkichlar', 'brandId': 'mid', 'brandName': 'Midea', 'isOwn': false, 'approved': false, 'addedByName': 'Aziz', 'requestsCount': 0},
  ];
  List<String> skillBrands = [];
  List<String> skillModels = [];

  http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Map<String, dynamic> get _skills => {
        'brands': [for (final b in brands.where((b) => skillBrands.contains(b['id']))) b],
        'models': [for (final m in models.where((m) => skillModels.contains(m['id']))) m],
      };

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/staff/directory', '');
    calls.add('${r.method} $path${r.body.isEmpty ? '' : ' ${r.body}'}');
    if (r.method == 'GET' && path == '/brands') return _json({'brands': brands});
    if (r.method == 'GET' && path == '/categories') return _json({'categories': ['Kir yuvish mashinalari', 'Muzlatkichlar']});
    if (r.method == 'GET' && path == '/models') {
      final q = r.url.queryParameters;
      return _json({
        'models': [
          for (final m in models)
            if ((q['brandId'] == null || m['brandId'] == q['brandId']) && (q['category'] == null || m['category'] == q['category']) && (q['approved'] != 'false' || m['approved'] == false)) m
        ],
      });
    }
    if (r.method == 'GET' && path == '/skills') return _json(_skills);
    if (r.method == 'PUT' && path == '/skills') {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      skillBrands = List<String>.from(body['brandIds'] as List);
      skillModels = List<String>.from(body['productIds'] as List);
      return _json(_skills);
    }
    final approve = RegExp(r'^/(brands|models)/([^/]+)/approve$').firstMatch(path);
    if (r.method == 'POST' && approve != null) {
      final list = approve.group(1) == 'brands' ? brands : models;
      for (final row in list) {
        if (row['id'] == approve.group(2)) row['approved'] = true;
      }
      return _json({'ok': true});
    }
    if (r.method == 'POST' && path == '/brands') {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final name = body['name'] as String;
      String key(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      final near = brands.where((b) => !(b['isOwn'] as bool) && key(b['name'] as String) != key(name) && (key(b['name'] as String).contains(key(name)) || key(name).contains(key(b['name'] as String))));
      if (near.isNotEmpty && body['force'] != true) {
        return _json({'error': 'A similar brand already exists', 'code': 'similarBrand', 'details': {'similar': [for (final b in near) {'id': b['id'], 'name': b['name']}]}}, 409);
      }
      final row = {'id': 'new-${brands.length}', 'name': name, 'isOwn': false, 'approved': false, 'addedByName': 'Me', 'modelCount': 0, 'pendingModels': 0, 'categories': <String>[]};
      brands.add(row);
      return _json({'brand': row, 'created': true}, 201);
    }
    if (r.method == 'POST' && path == '/models') {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      final row = {'id': 'nm-${models.length}', 'name': 'x ${body['model']}', 'sku': 'EXT-N', 'category': body['category'], 'brandId': body['brandId'], 'brandName': 'x', 'isOwn': false, 'approved': false, 'addedByName': 'Me', 'requestsCount': 0};
      models.add(row);
      return _json({'model': row, 'created': true}, 201);
    }
    if (r.method == 'DELETE') {
      calls.add('deleted');
      return _json({'ok': true});
    }
    return _json({'error': 'not found'}, 404);
  }
}

Future<void> _open(WidgetTester tester, _FakeDirectory fake, String role, Widget screen) async {
  SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
  await tester.runAsync(() => Translator.I.load());
  final session = StaffSession(httpClient: MockClient(fake.handle));
  session.user = StaffUser(id: 'u1', name: 'Tester', phone: '998900000001', role: role);
  session.restoring = false;
  await tester.pumpWidget(RizoApp(title: 'test', providers: [ChangeNotifierProvider<StaffSession>.value(value: session)], home: screen));
  await tester.pumpAndSettle();
  // The fake answers on real async time; let the screens receive it.
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the admin sees what waits for approval and approves a brand with one tap', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final fake = _FakeDirectory();
    await _open(tester, fake, 'admin', const DirectoryScreen());
    expect(find.text('Brands and models'), findsOneWidget);
    expect(find.text('2 entries wait for your approval'), findsOneWidget);
    expect(find.text('Brand: Midea'), findsOneWidget);
    expect(find.text('Model: Samsung RB37'), findsOneWidget); // a pending model of an approved brand
    await tester.tap(find.byTooltip('Approve').first);
    await tester.pumpAndSettle();
    expect(fake.calls.any((c) => c.startsWith('POST /brands/mid/approve')), isTrue);
    expect(fake.brands.firstWhere((b) => b['id'] == 'mid')['approved'], isTrue);
  });

  testWidgets('the front desk reads the directory but gets no approve or delete menus', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final fake = _FakeDirectory();
    await _open(tester, fake, 'receptionist', const DirectoryScreen());
    expect(find.text('Samsung'), findsOneWidget);
    expect(find.textContaining('wait for your approval'), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(fake.calls.any((c) => c.contains('approved=false')), isFalse);
  });

  testWidgets('a technician adds a whole brand to the "I repair" list and removes it again', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final fake = _FakeDirectory();
    await _open(tester, fake, 'technician', const SkillsScreen());
    expect(find.textContaining('Nothing listed yet'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samsung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to my list'));
    await tester.pumpAndSettle();
    expect(fake.skillBrands, ['sam']);
    expect(find.textContaining('Samsung · all models'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(InputChip), matching: find.byType(Icon))); // the chip's delete icon
    await tester.pumpAndSettle();
    expect(fake.skillBrands, isEmpty);
  });

  testWidgets('the device picker lists approved models only and reports the chosen one', (tester) async {
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final fake = _FakeDirectory();
    DirModel? chosen;
    await _open(tester, fake, 'receptionist', Scaffold(body: SingleChildScrollView(child: StatefulBuilder(builder: (context, setState) => OtherDevicePicker(value: chosen, onChanged: (m) => setState(() => chosen = m))))));
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(categoryLabel('Kir yuvish mashinalari')).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Samsung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(2));
    await tester.pumpAndSettle();
    expect(find.textContaining('Samsung RB37 (Waiting'), findsOneWidget); // listed but not selectable
    await tester.tap(find.text('Samsung WW70').last);
    await tester.pumpAndSettle();
    expect(chosen?.id, 'm1');
    expect(chosen?.approved, isTrue);
  });

  testWidgets('a near-duplicate brand is flagged, and added only when the person insists', (tester) async {
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final fake = _FakeDirectory();
    await _open(tester, fake, 'technician', Scaffold(body: Builder(builder: (context) => Center(child: ElevatedButton(onPressed: () => showAddDeviceSheet(context), child: const Text('open'))))));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Sams');
    await tester.tap(find.byType(DropdownButtonFormField<String?>).at(0));
    await tester.pumpAndSettle();
    await tester.tap(find.text(categoryLabel('Muzlatkichlar')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(1), 'WW99');
    await tester.tap(find.text('Add').last);
    await tester.pumpAndSettle();
    expect(find.text('A similar brand already exists:'), findsOneWidget);
    expect(find.text('• Samsung'), findsOneWidget);
    expect(fake.brands.any((b) => b['name'] == 'Sams'), isFalse);
    await tester.tap(find.text('Add anyway'));
    await tester.pumpAndSettle();
    expect(fake.brands.any((b) => b['name'] == 'Sams'), isTrue);
    expect(fake.models.any((m) => m['category'] == 'Muzlatkichlar' && m['name'] == 'x WW99'), isTrue);
  });
}
