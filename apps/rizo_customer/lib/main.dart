import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await Translator.I.load();
  await ThemeController.I.load();
  await PushService.I.init();
  final session = CustomerSession();
  await session.restore();
  runApp(CustomerApp(session: session));
}

class CustomerApp extends StatelessWidget {
  const CustomerApp({super.key, required this.session});
  final CustomerSession session;

  @override
  Widget build(BuildContext context) {
    return RizoApp(
      title: 'RIZO Service',
      providers: [ChangeNotifierProvider<CustomerSession>.value(value: session)],
      home: const CustomerGate(),
    );
  }
}
