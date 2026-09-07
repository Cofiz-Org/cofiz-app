import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import '../../_support/mock_http_client.dart';
import 'package:cofiz/core/services/auth_backend.dart';
import 'package:cofiz/core/config/relay_config.dart';

void main() {
  group('AuthBackend', () {
    test('requestOtp posts phone+provider and returns verificationId', () async {
      final mock = MockHttpClient();
      mock.onPost('/auth/whatsapp/start', (req) {
        expect(req['phone'], '+251911234567');
        expect(req['provider'], 'telegram');
        return jsonEncode({
          'challengeId': 'v1',
          'expiresIn': 300,
        });
      }, status: 200);
      final backend = AuthBackend(baseUrl: 'https://relay.example', client: mock);
      final r = await backend.requestOtp(phone: '+251911234567', provider: OtpProvider.telegram);
      expect(r.verificationId, 'v1');
      expect(r.expiresInSeconds, 300);
    });

    test('verifyOtp posts phone+provider+challenge and returns customToken', () async {
      final mock = MockHttpClient();
      mock.onPost('/auth/whatsapp/verify', (req) {
        expect(req['provider'], 'telegram');
        expect(req['challengeId'], 'v1');
        return jsonEncode({
          'customToken': 'tok',
          'uid': 'abc',
          'isNewUser': false,
        });
      }, status: 200);
      final backend = AuthBackend(baseUrl: 'https://relay.example', client: mock);
      final r = await backend.verifyOtp(
        phone: '+251911234567',
        provider: OtpProvider.telegram,
        verificationId: 'v1',
        code: '123456',
      );
      expect(r.customToken, 'tok');
      expect(r.uid, 'abc');
      expect(r.isNewUser, isFalse);
    });

    test('verifyOtp throws AuthBackendException on 400', () async {
      final mock = MockHttpClient();
      mock.onPost('/auth/whatsapp/verify', (_) => jsonEncode({'error': 'bad_code'}), status: 400);
      final backend = AuthBackend(baseUrl: 'https://relay.example', client: mock);
      expect(
        () => backend.verifyOtp(
          phone: '+251911234567',
          provider: OtpProvider.telegram,
          verificationId: 'v1',
          code: '000000',
        ),
        throwsA(isA<AuthBackendException>()),
      );
    });

    test('authTelegram posts fields and parses response', () async {
      final mock = MockHttpClient();
      mock.onPost('/auth/telegram', (req) => jsonEncode({
            'customToken': 'ttok',
            'uid': 'telegram:1',
            'isNewUser': true,
          }), status: 200);
      final backend = AuthBackend(baseUrl: 'https://relay.example', client: mock);
      final r = await backend.authTelegram(const {
        'id': '1',
        'first_name': 'A',
        'auth_date': '1700000000',
        'hash': 'abc',
      });
      expect(r.customToken, 'ttok');
      expect(r.uid, 'telegram:1');
      expect(r.isNewUser, isTrue);
    });

    test('authTelegram throws on 401 invalid_hash', () async {
      final mock = MockHttpClient();
      mock.onPost('/auth/telegram', (_) => jsonEncode({'error': 'invalid_hash'}), status: 401);
      final backend = AuthBackend(baseUrl: 'https://relay.example', client: mock);
      expect(
        () => backend.authTelegram(const {
          'id': '1',
          'first_name': 'A',
          'auth_date': '1',
          'hash': 'x',
        }),
        throwsA(isA<AuthBackendException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.errorCode, 'errorCode', 'invalid_hash')),
      );
    });

    test('register includes fcmToken when provided', () async {
      final mock = MockHttpClient();
      Map<String, dynamic>? sent;
      mock.onPost('/auth/register', (req) {
        sent = Map<String, dynamic>.from(req);
        return jsonEncode({'ok': true});
      }, status: 200);
      final backend = AuthBackend(baseUrl: 'https://relay.example', client: mock);
      await backend.register(
        phone: '+251911234567',
        displayName: 'A',
        companyName: 'C',
        requestedRole: 'admin',
        fcmToken: 'tok-123',
      );
      expect(sent!['fcmToken'], 'tok-123');
    });

    test('secret is sent as x-relay-secret header when non-empty', () async {
      final captured = <String, String>{};
      final mock = _HeaderCapturingClient(captured);
      mock.onPost('/auth/whatsapp/start', (_) => jsonEncode({
            'challengeId': 'v1',
            'expiresIn': 300,
          }), status: 200);
      final backend = AuthBackend(baseUrl: 'https://x', secret: 's3cr3t', client: mock);
      await backend.requestOtp(phone: '+251911234567', provider: OtpProvider.telegram);
      expect(captured['x-relay-secret'], 's3cr3t');
    });

    test('no x-relay-secret header when secret is null/empty', () async {
      RelayConfig.setForTest(secret: '');
      addTearDown(RelayConfig.resetForTest);
      final captured = <String, String>{};
      final mock = _HeaderCapturingClient(captured);
      mock.onPost('/auth/whatsapp/start', (_) => jsonEncode({
            'challengeId': 'v1',
            'expiresIn': 300,
          }), status: 200);
      final backend = AuthBackend(baseUrl: 'https://x', client: mock);
      await backend.requestOtp(phone: '+251911234567', provider: OtpProvider.telegram);
      expect(captured.containsKey('x-relay-secret'), isFalse);
    });
  });
}

class _HeaderCapturingClient extends MockHttpClient {
  _HeaderCapturingClient(this.captured);
  final Map<String, String> captured;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    captured.addAll(request.headers);
    return await super.send(request);
  }
}
