import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'auth_screens.dart';
import 'home_shell.dart';

class CustomerGate extends StatelessWidget {
  const CustomerGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<CustomerSession>();
    if (session.restoring) return const Scaffold(body: LoadingView());
    if (!session.isSignedIn) return const LoginScreen();
    return HomeShell(key: ValueKey(session.user!.id));
  }
}
