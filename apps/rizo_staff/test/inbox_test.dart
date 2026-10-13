import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:rizo_staff/admin/dashboard_screen.dart';
import 'package:rizo_staff/admin/service_quality_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The server's answers for the admin's first screen, in the same shape the API uses.
class _Fake {
  final List<String> calls = [];
  List<Map<String, dynamic>> inboxItems = [
    {'key': 'overdue', 'count': 2, 'tone': 'red', 'to': '/app/requests?overdue=1'},
    {'key': 'unassigned', 'count': 3, 'tone': 'orange', 'to': '/app/requests?technicianId=unassigned'},
    {'key': 'catalogPending', 'count': 1, 'tone': 'blue', 'to': '/app/directory'},
  ];

  http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Future<http.Response> handle(http.Request r) async {
    calls.add('${r.method} ${r.url.path}');
    if (r.url.path == '/api/staff/inbox') return _json({'items': inboxItems, 'total': inboxItems.fold<int>(0, (a, b) => a + (b['count'] as int))});
    if (r.url.path == '/api/staff/reports/dashboard') {
      return _json({
        'totals': {'requests': 21, 'revenue': 85000, 'profit': 1000, 'avgWorkMinutes': 90, 'avgResolutionHours': 36, 'avgRating': 4.5, 'legalOverdue': 1, 'debt': 0},
        'previous': null,
        'service': {'firstTimeFixRate': 62, 'callbackRate': 8, 'callbackCost': 150000, 'avgPartsWaitHours': 30},
        'parts': {'waitingRequests': 5, 'noOrder': 1, 'lateOrders': 1, 'openOrders': 4, 'lowStock': 2, 'toOrder': 3},
        'byStatus': [],
        'topProducts': [],
        'warrantySplit': {'free': 5, 'paid': 2},
      });
    }
    if (r.url.path == '/api/staff/requests') return _json({'requests': [], 'total': 0, 'hasMore': false});
    return _json({'error': 'not found'}, 404);
  }
}

Future<void> _open(WidgetTester tester, _Fake fake, Widget screen) async {
  tester.view.physicalSize = const Size(1000, 3200);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
  await tester.runAsync(() => Translator.I.load());
  final session = StaffSession(httpClient: MockClient(fake.handle));
  session.user = StaffUser(id: 'a1', name: 'Admin', phone: '998900000001', role: 'admin');
  session.restoring = false;
  await tester.pumpWidget(RizoApp(title: 'test', providers: [ChangeNotifierProvider<StaffSession>.value(value: session)], home: screen));
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the first screen shows "My work" and no longer the service-quality and spare-parts blocks', (tester) async {
    await _open(tester, _Fake(), const DashboardScreen());
    expect(find.text('MY WORK'), findsOneWidget);
    expect(find.text('6 things wait for you'), findsOneWidget);
    expect(find.text('Overdue jobs'), findsOneWidget);
    expect(find.text('Unassigned requests'), findsOneWidget);
    expect(find.text('Brands and models waiting for approval'), findsOneWidget);
    // the figures that moved away
    expect(find.text('First-time fix'.toUpperCase()), findsNothing);
    expect(find.textContaining('Spare parts', findRichText: false), findsNothing);
    expect(find.text('Requests'.toUpperCase()), findsWidgets); // the main numbers stay
  });

  testWidgets('a "My work" row opens the requests list with that filter already chosen', (tester) async {
    final fake = _Fake();
    await _open(tester, fake, const DashboardScreen());
    await tester.tap(find.text('Unassigned requests'));
    for (var i = 0; i < 3; i++) {
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    }
    await tester.pumpAndSettle();
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Unassigned'));
    expect(chip.selected, isTrue);
    expect(fake.calls, contains('GET /api/staff/requests'));
  });

  testWidgets('with nothing waiting the card says all is clear', (tester) async {
    final fake = _Fake()..inboxItems = [];
    await _open(tester, fake, const DashboardScreen());
    expect(find.textContaining('Nothing needs you right now'), findsOneWidget);
  });

  testWidgets('the service-quality screen carries the four figures that left the first screen', (tester) async {
    await _open(tester, _Fake(), const ServiceQualityScreen());
    expect(find.text('FIRST-TIME FIX'), findsOneWidget);
    expect(find.text('62%'), findsOneWidget);
    expect(find.text('8%'), findsOneWidget);
    expect(find.textContaining('150'), findsWidgets);
  });
}
