import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/providers/phone_otp_auth_provider.dart';
import 'package:cofiz/core/services/auth_backend.dart';

class _FakeBackend extends AuthBackend {
  _FakeBackend() : super(baseUrl: 'https://x', secret: 's');
  AuthBackendException? nextError;
  @override
  Future<VerifyOtpResult> authTelegram(Map<String, String> fields) async {
    if (nextError != null) throw nextError!;
    return VerifyOtpResult(customToken: 't', uid: 'u', isNewUser: false);
  }
  @override
  Future<VerifyOtpResult> verifyOtp({required String phone, required OtpProvider provider, required String verificationId, required String code}) async {
    if (nextError != null) throw nextError!;
    return VerifyOtpResult(customToken: 't', uid: 'u', isNewUser: false);
  }
  @override
  Future<RequestOtpResult> requestOtp({required String phone, required OtpProvider provider}) async =>
      RequestOtpResult(verificationId: 'v', expiresInSeconds: 60);
}

void main() {
  group('PhoneOtpAuthProvider error mapping', () {
    test('telegram_no_phone surfaces on completeTelegramLogin', () async {
      final p = PhoneOtpAuthProvider(backend: _FakeBackend());
      (p.backend as _FakeBackend).nextError = AuthBackendException(400, 'telegram_no_phone', 'no phone');
      await p.completeTelegramLogin(fields: {'id': '1', 'hash': 'x'});
      expect(p.state, OtpAuthState.error);
      expect(p.lastErrorCode, 'telegram_no_phone');
    });

    test('phone_not_registered surfaces on verifyOtp', () async {
      final p = PhoneOtpAuthProvider(backend: _FakeBackend());
      await p.requestOtp(phone: '+251911234567', provider: OtpProvider.whatsapp);
      (p.backend as _FakeBackend).nextError = AuthBackendException(403, 'phone_not_registered', 'nope');
      await p.verifyOtp(code: '000000');
      expect(p.state, OtpAuthState.error);
      expect(p.lastErrorCode, 'phone_not_registered');
    });
  });
}
