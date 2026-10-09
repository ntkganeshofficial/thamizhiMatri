import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../services/auth_service.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final auth = context.read<AuthService>();
    try {
      if (_register) {
        await auth.registerWithEmail(_email.text, _password.text);
      } else {
        await auth.signInWithEmail(_email.text, _password.text);
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      return _toast(context.trRead('Enter your email first'));
    }
    try {
      await context.read<AuthService>().sendPasswordReset(_email.text);
      if (mounted) _toast(context.trRead('Password reset email sent'));
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr(_register ? 'Create account' : 'Login')),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _form,
              child: Column(
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: context.tr('Email')),
                    validator: (v) => (v == null || !v.contains('@'))
                        ? context.trRead('Enter a valid email')
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: context.tr('Password'),
                    ),
                    validator: (v) => (v == null || v.length < 6)
                        ? context.trRead('Minimum 6 characters')
                        : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(context.tr(_register ? 'Register' : 'Login')),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _register = !_register),
                    child: Text(
                      context.tr(
                        _register
                            ? 'Already a member? Login'
                            : 'New here? Register free',
                      ),
                    ),
                  ),
                  if (!_register)
                    TextButton(
                      onPressed: _reset,
                      child: Text(context.tr('Forgot password?')),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
