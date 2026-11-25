import 'package:material_ui/material_ui.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../session/app_session.dart';
import '../../shell/tab_shell.dart';
import '../../theme.dart';

enum _Mode { signIn, signUp, reset }

/// Native sign-in, sign-up and password reset. Pops true once signed in.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _switch(_Mode mode) => setState(() {
        _mode = mode;
        _error = null;
        _notice = null;
      });

  Future<void> _submit() async {
    final session = TabShellScope.of(context).services.session;
    final email = _email.text.trim();
    final password = _password.text;
    final name = _name.text.trim();
    if (email.isEmpty || (_mode != _Mode.reset && password.isEmpty) || (_mode == _Mode.signUp && name.isEmpty)) {
      setState(() => _error = 'Please fill in every field.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      switch (_mode) {
        case _Mode.signIn:
          await session.signIn(email, password);
          if (mounted) Navigator.of(context).pop(true);
        case _Mode.signUp:
          final needsConfirmation = await session.signUp(name, email, password);
          if (!mounted) return;
          if (needsConfirmation) {
            setState(() {
              _mode = _Mode.signIn;
              _notice = 'Check your email to confirm your account, then sign in.';
            });
          } else {
            Navigator.of(context).pop(true);
          }
        case _Mode.reset:
          await session.sendPasswordReset(email);
          if (mounted) setState(() => _notice = 'We sent a reset link to $email.');
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on BannedException catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  InputDecoration _field(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: card,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
      );

  @override
  Widget build(BuildContext context) {
    final (title, subtitle, action) = switch (_mode) {
      _Mode.signIn => ('Maayong pagbalik', 'Sign in to your CraftCebu account.', 'Sign in'),
      _Mode.signUp => ('Create an account', 'Buy from Cebuano makers and track your orders.', 'Create account'),
      _Mode.reset => ('Forgot password', "We'll email you a link to set a new one.", 'Send reset link'),
    };
    return Scaffold(
      appBar: AppBar(backgroundColor: paper, surfaceTintColor: paper),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(title, style: display(32)),
            const SizedBox(height: 6),
            Text(subtitle, style: body(15, color: muted)),
            const SizedBox(height: 28),
            if (_mode == _Mode.signUp) ...[
              TextField(
                key: const ValueKey('name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                style: body(16),
                decoration: _field('Full name'),
              ),
              const SizedBox(height: 14),
            ],
            TextField(
              key: const ValueKey('email'),
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              autofillHints: const [AutofillHints.email],
              style: body(16),
              decoration: _field('Email'),
            ),
            if (_mode != _Mode.reset) ...[
              const SizedBox(height: 14),
              TextField(
                key: const ValueKey('password'),
                controller: _password,
                obscureText: true,
                autofillHints: [_mode == _Mode.signUp ? AutofillHints.newPassword : AutofillHints.password],
                style: body(16),
                decoration: _field('Password'),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: body(14, color: atsuete)),
            ],
            if (_notice != null) ...[
              const SizedBox(height: 14),
              Text(_notice!, style: body(14, color: const Color(0xFF2F7D4E))),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52), textStyle: body(16, weight: 600)),
              child: _busy ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)) : Text(action),
            ),
            const SizedBox(height: 12),
            if (_mode == _Mode.signIn) ...[
              TextButton(onPressed: () => _switch(_Mode.reset), child: const Text('Forgot password?')),
              TextButton(onPressed: () => _switch(_Mode.signUp), child: const Text('Create an account')),
            ] else
              TextButton(onPressed: () => _switch(_Mode.signIn), child: const Text('I already have an account')),
          ],
        ),
      ),
    );
  }
}
