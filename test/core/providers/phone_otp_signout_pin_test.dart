import 'dart:convert';

import 'package:cofiz/core/providers/phone_otp_auth_provider.dart';
import 'package:cofiz/core/services/auth_backend.dart';
import 'package:cofiz/core/services/auth_backend_firebase.dart';
import 'package:cofiz/core/services/pin_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  final Map<String, String> store = {};
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    switch (call.method) {
      case 'read':
        return store[call.arguments['key']];
      case 'write':
        store[call.arguments['key']] = call.arguments['value'];
        return null;
      case 'delete':
        store.remove(call.arguments['key']);
        return null;
      case 'readAll':
        return Map<String, String>.from(store);
      case 'deleteAll':
        store.clear();
        return null;
      default:
        return null;
    }
  });

  setUp(() => store.clear());

  test('signOut clears the per-uid PIN so re-login goes to PIN setup',
      () async {
    final backend = AuthBackend(
      baseUrl: 'https://x',
      secret: 's',
      client: MockClient((req) async => http.Response(
          jsonEncode({
            'customToken': 'tok',
            'uid': 'userX',
            'isNewUser': false,
          }),
          200)),
    );
    final pinService = PinService(storage: const FlutterSecureStorage());
    final provider = PhoneOtpAuthProvider(
      backend: backend,
      firebaseAuth: AuthBackendFirebase(),
      pinService: pinService,
    );

    await provider.completeTelegramNative(idToken: 'id-token');
    expect(provider.uid, 'userX');

    await pinService.setPin('482917', uid: 'userX');
    expect(await pinService.hasPin(uid: 'userX'), isTrue);

    await provider.signOut();

    expect(await pinService.hasPin(uid: 'userX'), isFalse);
  });
}
