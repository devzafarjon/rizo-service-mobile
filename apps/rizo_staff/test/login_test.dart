import 'package:flutter_test/flutter_test.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:rizo_staff/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows the sign-in screen when nobody is signed in', (tester) async {
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
    await tester.runAsync(() => Translator.I.load());
    final session = StaffSession()..restoring = false;
    await tester.pumpWidget(StaffApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('For technicians and staff'), findsOneWidget);
  });

  testWidgets('language can be switched on the sign-in screen', (tester) async {
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
    await tester.runAsync(() => Translator.I.load());
    final session = StaffSession()..restoring = false;
    await tester.pumpWidget(StaffApp(session: session));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(LanguageButton));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Русский').last);
    await tester.pumpAndSettle();
    expect(find.text('Войти'), findsOneWidget);
  });
}
