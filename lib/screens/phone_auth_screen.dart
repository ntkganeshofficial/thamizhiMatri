import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/l10n.dart';
import '../services/auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  String _countryCode = '+91';
  OtpSession? _confirmation;
  bool _busy = false;
  StreamSubscription<User?>? _authSub;

  @override
  void initState() {
    super.initState();
    // Android may sign in automatically via SMS auto-retrieval.
    _authSub = context.read<AuthService>().authState.listen((user) {
      if (user != null && mounted) {
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final number = _phone.text.trim();
    if (number.length < 7) {
      return _toast(context.trRead('Enter a valid mobile number'));
    }
    setState(() => _busy = true);
    try {
      final result = await context.read<AuthService>().sendOtp(
        '$_countryCode$number',
      );
      setState(() => _confirmation = result);
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_otp.text.trim().length != 6) {
      return _toast(context.trRead('Enter the 6-digit OTP'));
    }
    setState(() => _busy = true);
    try {
      await _confirmation!.confirm(_otp.text.trim());
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? e.code);
    } catch (e) {
      _toast('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final otpStage = _confirmation != null;
    return Scaffold(
      appBar: AppBar(title: Text(context.tr('Mobile verification'))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                if (!otpStage) ...[
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: DropdownButtonFormField<String>(
                          initialValue: _countryCode,
                          items:
                              const [
                                    '+91',
                                    '+94',
                                    '+65',
                                    '+60',
                                    '+971',
                                    '+1',
                                    '+44',
                                    '+61',
                                  ]
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) => setState(() => _countryCode = v!),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: context.tr('Mobile number'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      context.tr('OTP will be sent to this number'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _sendOtp,
                    child: Text(context.tr('Send OTP')),
                  ),
                ] else ...[
                  Text(
                    '${context.tr('Enter the OTP sent to')} $_countryCode${_phone.text.trim()}',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _otp,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(labelText: context.tr('OTP')),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy ? null : _verify,
                    child: Text(context.tr('Verify & Continue')),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _confirmation = null),
                    child: Text(context.tr('Change number')),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
