import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:rizo_staff/main.dart';
import 'package:rizo_staff/tech/stock_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('two-step sign-in: the code field appears when the server asks for it, and the code goes with the next try', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
    await tester.runAsync(() => Translator.I.load());
    final bodies = <Map<String, dynamic>>[];
    final client = MockClient((r) async {
      if (r.url.path == '/api/staff/auth/login') {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body['code'] == null) return _json({'error': 'Enter the six-digit code', 'code': 'totpRequired'}, 401);
        if (body['code'] != '123456') return _json({'error': 'Wrong code', 'code': 'totpInvalid'}, 401);
        return _json({'token': 'tok', 'user': {'id': 'u1', 'name': 'Admin', 'phone': '998900000001', 'role': 'admin', 'locale': 'en'}});
      }
      return _json({'error': 'not found'}, 404);
    });
    final session = StaffSession(httpClient: client)..restoring = false;
    await tester.pumpWidget(StaffApp(session: session));
    await _settle(tester);
    expect(find.byType(TextField), findsNWidgets(2)); // phone and password
    await tester.enterText(find.byType(TextField).at(0), '998900000001');
    await tester.enterText(find.byType(TextField).at(1), 'admin123');
    await tester.tap(find.text('Sign in'));
    await _settle(tester);
    expect(find.byType(TextField), findsNWidgets(3)); // the code field joined
    expect(find.textContaining('code', findRichText: false), findsWidgets);
    await tester.enterText(find.byType(TextField).at(2), '000000');
    await tester.tap(find.text('Sign in'));
    await _settle(tester);
    expect(bodies.last['code'], '000000');
    expect(find.text(tr('errors.totpInvalid')), findsOneWidget); // the wrong code is explained in the person's language, not a crash
    await tester.enterText(find.byType(TextField).at(2), '123456');
    await tester.tap(find.text('Sign in'));
    // after a successful sign-in the home screen starts loading (a spinner never settles), so only let the request finish
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(bodies.last['code'], '123456');
    expect(session.isSignedIn, isTrue);
  });

  testWidgets('"My stock": the parts the technician carries, with their quantities', (tester) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
    await tester.runAsync(() => Translator.I.load());
    final client = MockClient((r) async {
      if (r.url.path == '/api/staff/my-jobs/stock') {
        return _json({'stock': [{'id': 's1', 'name': 'Compressor', 'nameUz': 'Kompressor', 'nameRu': 'Компрессор', 'nameEn': 'Compressor', 'quantity': 3}, {'id': 's2', 'name': 'Thermostat', 'nameUz': 'Termostat', 'nameRu': 'Термостат', 'nameEn': 'Thermostat', 'quantity': 1}]});
      }
      if (r.url.path == '/api/staff/my-jobs/transfers') return _json({'transfers': []});
      return _json({'error': 'not found'}, 404);
    });
    final session = StaffSession(httpClient: client);
    session.user = StaffUser(id: 't1', name: 'Tech', phone: '998900000002', role: 'technician', technicianType: 'mobile');
    session.restoring = false;
    await tester.pumpWidget(RizoApp(title: 'test', providers: [ChangeNotifierProvider<StaffSession>.value(value: session)], home: const StockScreen()));
    await _settle(tester);
    expect(find.text('Compressor'), findsOneWidget);
    expect(find.text('Thermostat'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget); // ask a warehouse for parts for the van
  });

  testWidgets('"My stock" with nothing in the van says so', (tester) async {
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
    await tester.runAsync(() => Translator.I.load());
    final client = MockClient((r) async => r.url.path == '/api/staff/my-jobs/stock' ? _json({'stock': []}) : r.url.path == '/api/staff/my-jobs/transfers' ? _json({'transfers': []}) : _json({'error': 'x'}, 404));
    final session = StaffSession(httpClient: client);
    session.user = StaffUser(id: 't1', name: 'Tech', phone: '998900000002', role: 'technician', technicianType: 'mobile');
    session.restoring = false;
    await tester.pumpWidget(RizoApp(title: 'test', providers: [ChangeNotifierProvider<StaffSession>.value(value: session)], home: const StockScreen()));
    await _settle(tester);
    expect(find.text(tr('techStock.mineEmpty')), findsOneWidget);
  });
}
