import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  await Translator.I.load();
  final session = StaffSession();
  await session.restore();
  runApp(StaffApp(session: session));
}

class StaffApp extends StatelessWidget {
  const StaffApp({super.key, required this.session});
  final StaffSession session;

  @override
  Widget build(BuildContext context) {
    return RizoApp(
      title: 'RIZO Texnik',
      providers: [ChangeNotifierProvider<StaffSession>.value(value: session)],
      home: const StaffGate(),
    );
  }
}
