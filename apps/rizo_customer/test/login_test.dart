import 'package:flutter_test/flutter_test.dart';
import 'package:rizo_core/rizo_core.dart';
import 'package:rizo_customer/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('sign-in screen offers sign up, forgot password, tracking and service centers', (tester) async {
    SharedPreferences.setMockInitialValues({'rizo_locale': 'en'});
    await tester.runAsync(() => Translator.I.load());
    final session = CustomerSession()..restoring = false;
    await tester.pumpWidget(CustomerApp(session: session));
    await tester.pumpAndSettle();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Track a request'), findsOneWidget);
    expect(find.text('Service centers'), findsOneWidget);
  });
}
