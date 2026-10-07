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
    // Accountants and warehouse managers work on the website.
    if (!user.usesApp) return _WebOnly(user: user);
    // Keyed by user so a different account never sees the previous one's data.
    return user.isTechnician ? TechHome(key: ValueKey('tech-${user.id}')) : AdminHome(key: ValueKey('admin-${user.id}'));
  }
}

/// The app is for technicians, the front desk and admins; other roles are pointed to the website.
class _WebOnly extends StatelessWidget {
  const _WebOnly({required this.user});
  final StaffUser user;

  @override
  Widget build(BuildContext context) {
    context.watch<Translator>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const LogoMark(height: 56),
              const SizedBox(height: 20),
              Text(user.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(context.tr('mobile.webOnly'), textAlign: TextAlign.center, style: TextStyle(color: Brand.muted)),
              const SizedBox(height: 20),
              FilledButton(onPressed: () => openUri(context, Uri.parse(AppConfig.webUrl)), child: Text(context.tr('mobile.openWebsite'))),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.read<StaffSession>().logout(), child: Text(context.tr('common.signOut'))),
            ]),
          ),
        ),
      ),
    );
  }
}
