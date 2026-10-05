import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    final password = _password.text;
    if (phone.isEmpty || password.isEmpty) {
      setState(() => _error = context.tr('errors.required'));
      return;
    }
    setState(() => _error = null);
    try {
      final user = await context.read<StaffSession>().login(phone, password);
      if (user.role == 'customer') return;
    } catch (error) {
      if (mounted) setState(() => _error = context.errorText(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Align(alignment: Alignment.centerRight, child: LanguageButton()),
                const SizedBox(height: 8),
                const Center(child: LogoMark(height: 64)),
                const SizedBox(height: 12),
                Center(child: Text(context.tr('brand.service'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Brand.ink))),
                const SizedBox(height: 4),
                Center(child: Text(context.tr('mobile.staffSubtitle'), style: const TextStyle(color: Color(0xFF6B7280)))),
                const SizedBox(height: 28),
                Labeled(context.tr('common.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone, autofillHints: const [AutofillHints.username], textInputAction: TextInputAction.next, decoration: const InputDecoration(hintText: '+998 90 123 45 67'))),
                Labeled(
                  context.tr('common.password'),
                  child: TextField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure))),
                  ),
                ),
                if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: const TextStyle(color: Brand.red, fontWeight: FontWeight.w700))),
                BusyButton(label: context.tr('common.signIn'), onPressed: _submit),
                const SizedBox(height: 8),
                const Center(child: ServerLink()),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
