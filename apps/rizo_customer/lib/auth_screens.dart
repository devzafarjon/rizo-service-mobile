import 'package:flutter/material.dart';
import 'package:rizo_core/rizo_core.dart';

import 'centers_screen.dart';
import 'track_screen.dart';

Widget _frame(BuildContext context, {required List<Widget> children, bool back = false}) {
  return Scaffold(
    appBar: back ? AppBar(actions: const [LanguageButton()]) : null,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)),
        ),
      ),
    ),
  );
}

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
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = context.tr('errors.required'));
      return;
    }
    setState(() => _error = null);
    try {
      await context.read<CustomerSession>().login(_phone.text.trim(), _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = context.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _frame(context, children: [
      const Align(alignment: Alignment.centerRight, child: LanguageButton()),
      const Center(child: LogoMark(height: 64)),
      const SizedBox(height: 10),
      Center(child: Text(context.tr('brand.service'), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
      const SizedBox(height: 4),
      Center(child: Text(context.tr('mobile.customerSubtitle'), textAlign: TextAlign.center, style: TextStyle(color: Brand.muted))),
      const SizedBox(height: 26),
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
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: Brand.red, fontWeight: FontWeight.w700))),
      BusyButton(label: context.tr('common.signIn'), onPressed: _submit),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ForgotScreen())), child: Text(context.tr('mobile.forgot'), overflow: TextOverflow.ellipsis))),
        Flexible(child: TextButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SignupScreen())), child: Text(context.tr('mobile.signup'), overflow: TextOverflow.ellipsis))),
      ]),
      const Divider(height: 28),
      OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const TrackScreen())), icon: const Icon(Icons.search), label: Text(context.tr('home.track'))),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CentersScreen())), icon: const Icon(Icons.place_outlined), label: Text(context.tr('home.centers'))),
      const SizedBox(height: 8),
      const Center(child: ServerLink()),
    ]);
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _address = TextEditingController();
  String? _error;

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty || _password.text.length < 6) {
      setState(() => _error = context.tr('errors.passwordLength'));
      return;
    }
    setState(() => _error = null);
    try {
      await context.read<CustomerSession>().signup(name: _name.text.trim(), phone: _phone.text.trim(), password: _password.text, address: _address.text);
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = context.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _frame(context, back: true, children: [
      Text(context.tr('mobile.signup'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 18),
      Labeled(context.tr('common.name'), child: TextField(controller: _name, textCapitalization: TextCapitalization.words)),
      Labeled(context.tr('common.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone)),
      Labeled(context.tr('common.password'), hint: context.tr('errors.passwordLength'), child: TextField(controller: _password, obscureText: true)),
      Labeled('${context.tr('common.address')} (${context.tr('common.optional')})', child: TextField(controller: _address)),
      if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: Brand.red, fontWeight: FontWeight.w700))),
      BusyButton(label: context.tr('mobile.signup'), onPressed: _submit),
    ]);
  }
}

class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override
  State<ForgotScreen> createState() => _ForgotScreenState();
}

class _ForgotScreenState extends State<ForgotScreen> {
  final _phone = TextEditingController();
  bool _sent = false;
  String? _error;

  Future<void> _submit() async {
    if (_phone.text.trim().isEmpty) return;
    try {
      await context.read<CustomerSession>().forgotPassword(_phone.text.trim());
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) setState(() => _error = context.errorText(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _frame(context, back: true, children: [
      Text(context.tr('mobile.forgot'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text(context.tr('mobile.forgotHint'), style: TextStyle(color: Brand.muted)),
      const SizedBox(height: 18),
      if (_sent)
        Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Brand.greenTint, borderRadius: BorderRadius.circular(14)), child: Text(context.tr('mobile.forgotSent'), style: TextStyle(color: Brand.green, fontWeight: FontWeight.w800)))
      else ...[
        Labeled(context.tr('common.phone'), child: TextField(controller: _phone, keyboardType: TextInputType.phone)),
        if (_error != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(_error!, style: TextStyle(color: Brand.red, fontWeight: FontWeight.w700))),
        BusyButton(label: context.tr('mobile.sendPassword'), onPressed: _submit),
      ],
    ]);
  }
}
