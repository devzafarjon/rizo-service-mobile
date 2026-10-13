import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:rizo_staff/admin/automation_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The auto-jobs API as the server answers it (same field names), kept in memory.
class _FakeAuto {
  final List<String> calls = [];
  Map<String, dynamic> settings = {'deadlineEnabled': true, 'deadlineWarningPercent': 25, 'legalWarningDays': 3, 'dailyEnabled': true, 'dailyReportHour': 18, 'payrollEnabled': true, 'payrollPeriod': 'weekly', 'weeklyEnabled': true};
  Map<String, dynamic>? dailyLast;

  http.Response _json(Object body, [int status = 200]) => http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json; charset=utf-8'});

  Map<String, dynamic> _run(String key, Map<String, dynamic> summary, {String trigger = 'auto'}) =>
      {'id': 'r-$key', 'jobKey': key, 'trigger': trigger, 'ok': true, 'summary': summary, 'error': null, 'ranByName': trigger == 'manual' ? 'Admin' : null, 'startedAt': '2026-10-13T12:00:00.000Z', 'finishedAt': '2026-10-13T12:00:01.000Z'};

  Future<http.Response> handle(http.Request r) async {
    final path = r.url.path.replaceFirst('/api/staff/auto-jobs', '');
    calls.add('${r.method} $path${r.body.isEmpty ? '' : ' ${r.body}'}');
    if (r.method == 'GET' && path.isEmpty) {
      return _json({
        'settings': settings,
        'jobs': [
          {'key': 'deadline_watch', 'schedule': {'type': 'minutely'}, 'enabled': settings['deadlineEnabled'], 'lastRun': _run('deadline_watch', {'atRisk': 2, 'warned': 1}), 'lastAutoRun': null, 'overdueSince': null},
          {'key': 'daily_report', 'schedule': {'type': 'daily', 'hour': 18}, 'enabled': settings['dailyEnabled'], 'lastRun': dailyLast, 'lastAutoRun': null, 'overdueSince': null},
          {'key': 'weekly_digest', 'schedule': {'type': 'weekly', 'weekday': 1, 'hour': 9}, 'enabled': true, 'lastRun': null, 'lastAutoRun': null, 'overdueSince': null},
          {'key': 'payroll_statements', 'schedule': {'type': 'weekly', 'weekday': 1, 'hour': 9.5}, 'enabled': true, 'lastRun': null, 'lastAutoRun': null, 'overdueSince': '2026-10-12T04:30:00.000Z'},
        ],
      });
    }
    if (r.method == 'GET' && path == '/at-risk') {
      return _json({'items': [{'id': 'req1', 'displayId': '131026010015', 'product': 'RIZO Frost 280', 'status': 'new', 'priority': 'medium', 'technician': {'id': 't1', 'name': 'Aziz Rakhimov'}, 'kind': 'sla', 'remainingMs': 7200000, 'percentLeft': 10, 'dueAt': '2026-10-13T14:00:00Z'}], 'warningPercent': 25, 'legalWarningDays': 3});
    }
    if (r.method == 'GET' && path == '/history') {
      return _json({'runs': [?dailyLast, _run('weekly_digest', {'from': '2026-10-05', 'to': '2026-10-11', 'created': 9, 'finished': 7, 'open': 4, 'overdue': 1, 'revenue': 1200000, 'avgRating': 4.5})]});
    }
    if (r.method == 'GET' && path == '/statements') {
      return _json({'statements': [{'id': 's1', 'from': '2026-10-05', 'to': '2026-10-11', 'kind': 'auto', 'jobs': 6, 'jobsTotal': 450000, 'adjustmentsTotal': -50000, 'total': 400000, 'createdAt': '2026-10-12T04:30:00Z', 'technician': {'id': 't1', 'name': 'Aziz Rakhimov'}}]});
    }
    if (r.method == 'POST' && path == '/daily_report/run') {
      dailyLast = _run('daily_report', {'date': '2026-10-13', 'created': 3, 'finished': 2, 'open': 26, 'overdue': 18, 'atRisk': 0, 'partsWaiting': 5, 'collected': 150000, 'avgRating': null, 'topTechnician': {'name': 'Aziz Rakhimov', 'done': 2}}, trigger: 'manual');
      return _json({'run': dailyLast});
    }
    if (r.method == 'PATCH' && path == '/settings') {
      settings = {...settings, ...(jsonDecode(r.body) as Map<String, dynamic>)};
      return _json({'settings': settings});
    }
    return _json({'error': 'not found'}, 404);
  }
}

Future<void> _open(WidgetTester tester, _FakeAuto fake, {bool dark = false}) async {
  tester.view.physicalSize = const Size(1000, 6000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
  await tester.runAsync(() => Translator.I.load());
  if (dark) {
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en', 'rizo_theme': 'dark'});
    await tester.runAsync(() => ThemeController.I.load());
    addTearDown(() async {
      SharedPreferences.setMockInitialValues({'rizo_theme': 'light'});
      await ThemeController.I.load();
    });
  }
  final session = StaffSession(httpClient: MockClient(fake.handle));
  session.user = StaffUser(id: 'a1', name: 'Admin', phone: '998900000001', role: 'admin');
  session.restoring = false;
  await tester.pumpWidget(RizoApp(title: 'test', providers: [ChangeNotifierProvider<StaffSession>.value(value: session)], home: const AutomationScreen()));
  await tester.pumpAndSettle();
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
  }
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the four jobs, their schedule and last result, the at-risk job, reports and pay statements', (tester) async {
    await _open(tester, _FakeAuto());
    expect(find.text('Automatic tasks'), findsOneWidget);
    for (final title in ['Deadline watch', 'Daily report', 'Weekly report', 'Payroll']) {
      expect(find.text(title), findsWidgets);
    }
    expect(find.text('Every minute'), findsOneWidget);
    expect(find.text('Every day at 18:00'), findsOneWidget);
    expect(find.text('Every Monday at 09:30'), findsOneWidget);
    expect(find.text('2 at risk, 1 warned'), findsOneWidget);
    expect(find.text('Never run yet'), findsWidgets);
    expect(find.textContaining('it will run by itself as soon as the server is awake'), findsOneWidget);
    expect(find.textContaining('RIZO Frost 280'), findsOneWidget);
    expect(find.text('Aziz Rakhimov · Status timer'), findsOneWidget);
    expect(find.text('WEEK 2026-10-05 – 2026-10-11'), findsOneWidget);
    expect(find.textContaining('Aziz Rakhimov'), findsWidgets);
    expect(find.textContaining('Jobs: 6'), findsOneWidget);
  });

  testWidgets('night mode: the Automatic tasks screen draws without errors', (tester) async {
    await _open(tester, _FakeAuto(), dark: true);
    expect(Brand.dark, isTrue);
    expect(find.text('Automatic tasks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('"Run now" runs the daily report on the server and shows its result', (tester) async {
    final fake = _FakeAuto();
    await _open(tester, fake);
    await tester.tap(find.text('Run now').at(1)); // second job = daily report
    await _settle(tester);
    expect(fake.calls, contains('POST /daily_report/run'));
    expect(find.text('3 new, 2 finished, 26 open, 18 overdue'), findsWidgets); // last-run line
    expect(find.text('DAILY REPORT, 2026-10-13'), findsOneWidget); // report history card
    expect(find.textContaining('Busiest technician: Aziz Rakhimov (2 jobs)'), findsOneWidget);
  });

  testWidgets('switching a task off and saving the numbers go to the server', (tester) async {
    final fake = _FakeAuto();
    await _open(tester, fake);
    await tester.tap(find.byType(Switch).first);
    await _settle(tester);
    expect(fake.calls.any((c) => c == 'PATCH /settings {"deadlineEnabled":false}'), isTrue);
    expect(fake.settings['deadlineEnabled'], isFalse);
    await tester.enterText(find.byType(TextField).at(2), '20');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    expect(fake.settings['dailyReportHour'], 20);
    expect(fake.settings['deadlineWarningPercent'], 25);
  });
}
