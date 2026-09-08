import 'package:firebase_auth/firebase_auth.dart';

import '../config/relay_config.dart';
import 'auth_backend.dart';

String? currentAccountEmail({String? fallback}) {
  final authEmail = FirebaseAuth.instance.currentUser?.email;
  if (authEmail != null && authEmail.isNotEmpty) return authEmail;
  return (fallback == null || fallback.isEmpty) ? null : fallback;
}

class EmailVerificationService {
  AuthBackend get _backend => AuthBackend(
        baseUrl: RelayConfig.relayUrl.isNotEmpty
            ? RelayConfig.relayUrl
            : 'https://cofiz.natanim.dev',
        secret: RelayConfig.relaySecret,
      );

  Future<void> requestCode(String? fallbackEmail) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw EmailVerificationException('Please sign in first.');
    }
    try {
      await _backend.requestEmailCode(uid: uid);
    } on AuthBackendException catch (e) {
      switch (e.errorCode) {
        case 'network_error':
          throw EmailVerificationException(
              'Network error. Check your connection and try again.');
        case 'cooldown':
          throw EmailVerificationException(
              'Please wait a minute before requesting a new code.');
        case 'no_email':
          throw EmailVerificationException(
              'Your account has no email address to verify.');
        case 'email_unavailable':
        case 'email_send_failed':
          throw EmailVerificationException(
              'Verification service unavailable. Try again later.');
        case 'rate_limited':
          throw EmailVerificationException(
              'Too many requests. Try again later.');
        default:
          throw EmailVerificationException(
              e.message.isNotEmpty
                  ? e.message
                  : 'Could not send code. Try again.');
      }
    } catch (_) {
      throw EmailVerificationException(
          'Network error. Check your connection and try again.');
    }
  }

  Future<bool> verifyCode(String code) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw EmailVerificationException('Please sign in first.');
    }
    try {
      final ok = await _backend.verifyEmailCode(uid: uid, code: code);
      return ok;
    } on AuthBackendException catch (e) {
      switch (e.errorCode) {
        case 'network_error':
          throw EmailVerificationException(
              'Network error. Check your connection and try again.');
        case 'too_many':
          throw EmailVerificationException('Too many attempts. Resend code.',
              locked: true);
        case 'not_found':
          throw EmailVerificationException(
              'No code requested yet. Tap resend.');
        case 'bad_code':
          throw EmailVerificationException('Invalid code. Try again.');
        default:
          throw EmailVerificationException(
              e.message.isNotEmpty ? e.message : 'Invalid or expired code.');
      }
    } catch (_) {
      throw EmailVerificationException(
          'Network error. Check your connection and try again.');
    }
  }
}

class EmailVerificationException implements Exception {
  final String message;
  final bool locked;
  EmailVerificationException(this.message, {this.locked = false});
  @override
  String toString() => message;
}
