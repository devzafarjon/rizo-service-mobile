import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rizo_core/rizo_core.dart';

import 'gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockTabletToLandscape();
  await AppConfig.load();
  await Translator.I.load();
  await ThemeController.I.load();
  await PushService.I.init();
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

/// On a tablet the technician board always opens sideways (four columns); phones keep their normal rotation.
Future<void> _lockTabletToLandscape() async {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final shortestSide = view.physicalSize.shortestSide / view.devicePixelRatio;
  if (shortestSide >= 600) {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  }
}
