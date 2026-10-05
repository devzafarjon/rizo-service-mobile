import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'admin/admin_home.dart';
import 'login_screen.dart';
import 'tech/tech_home.dart';

/// Chooses the right screen for who is signed in.
class StaffGate extends StatelessWidget {
  const StaffGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<StaffSession>();
    if (session.restoring) return const Scaffold(body: LoadingView());
    final user = session.user;
    if (!session.isSignedIn || user == null) return const LoginScreen();
    // Keyed by user so a different account never sees the previous one's data.
    return user.isTechnician ? TechHome(key: ValueKey('tech-${user.id}')) : AdminHome(key: ValueKey('admin-${user.id}'));
  }
}
