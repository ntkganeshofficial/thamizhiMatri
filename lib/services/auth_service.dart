import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// A pending phone verification; call [confirm] with the SMS code.
abstract class OtpSession {
  Future<void> confirm(String code);
}

class _WebOtp implements OtpSession {
  final ConfirmationResult _result;
  _WebOtp(this._result);

  @override
  Future<void> confirm(String code) => _result.confirm(code);
}

class _MobileOtp implements OtpSession {
  final FirebaseAuth _auth;
  final String _verificationId;
  _MobileOtp(this._auth, this._verificationId);

  @override
  Future<void> confirm(String code) => _auth.signInWithCredential(
    PhoneAuthProvider.credential(
      verificationId: _verificationId,
      smsCode: code,
    ),
  );
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authState => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> registerWithEmail(String email, String password) => _auth
      .createUserWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  /// Web uses signInWithPhoneNumber (reCAPTCHA); Android/iOS only support verifyPhoneNumber.
  Future<OtpSession> sendOtp(String e164Phone) async {
    if (kIsWeb) return _WebOtp(await _auth.signInWithPhoneNumber(e164Phone));

    final completer = Completer<OtpSession>();
    await _auth.verifyPhoneNumber(
      phoneNumber: e164Phone,
      verificationCompleted: (credential) async {
        // Android instant verification / SMS auto-retrieval.
        try {
          await _auth.signInWithCredential(credential);
        } on FirebaseAuthException catch (_) {}
      },
      verificationFailed: (e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (verificationId, _) {
        if (!completer.isCompleted) {
          completer.complete(_MobileOtp(_auth, verificationId));
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );
    return completer.future;
  }

  Future<void> signOut() => _auth.signOut();
}
