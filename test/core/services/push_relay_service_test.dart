import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cofiz/core/services/push_relay_service.dart';

void main() {
  group('PushRelayService', () {
    late FakeFirebaseFirestore fake;
    late List<http.Request> requests;
    late http.Client mockClient;

    setUp(() {
      fake = FakeFirebaseFirestore();
      requests = [];
      mockClient = MockClient((request) async {
        requests.add(request);
        return http.Response('{"sent":true}', 200);
      });
    });

    PushRelayService service() => PushRelayService(
          firestore: fake,
          httpClient: mockClient,
          relayUrl: 'https://relay.example.com/push',
          relaySecret: 'secret123',
        );

    Future<void> seedUser(String uid, {bool? pushEnabled}) async {
      await fake.collection('users').doc(uid).set({
        if (pushEnabled != null) 'pushNotificationsEnabled': pushEnabled,
      });
    }

    test('posts Cofiz title/body/type with relay secret header', () async {
      await seedUser('u1');
      final ok = await service().sendPush(
        targetUserId: 'u1',
        title: 'Money Received',
        body: 'You received ETB 100',
        type: 'moneyDistributed',
      );
      expect(ok, isTrue);
      expect(requests, hasLength(1));
      final req = requests.single;
      expect(req.headers['X-Relay-Secret'], 'secret123');
      final payload = jsonDecode(req.body) as Map<String, dynamic>;
      expect(payload['targetUserId'], 'u1');
      expect(payload['title'], 'Cofiz');
      expect(payload['body'], 'You received ETB 100');
      expect(payload['type'], 'moneyDistributed');
    });

    test('skips HTTP when user opted out (no request sent)', () async {
      await seedUser('u2', pushEnabled: false);
      final ok = await service().sendPush(
        targetUserId: 'u2',
        title: 'Ping',
        body: 'hi',
        type: 'ping',
      );
      expect(ok, isFalse);
      expect(requests, isEmpty);
    });

    test('sends when flag absent (opt-in by default)', () async {
      await seedUser('u3');
      final ok = await service().sendPush(
        targetUserId: 'u3',
        title: 'Ping',
        body: 'hi',
        type: 'ping',
      );
      expect(ok, isTrue);
      expect(requests, hasLength(1));
    });

    test('returns false without network when relay unconfigured', () async {
      await seedUser('u4');
      final svc = PushRelayService(
        firestore: fake,
        httpClient: mockClient,
        relayUrl: '',
        relaySecret: '',
      );
      final ok = await svc.sendPush(
        targetUserId: 'u4',
        title: 'Ping',
        body: 'hi',
        type: 'ping',
      );
      expect(ok, isFalse);
      expect(requests, isEmpty);
    });

    test('returns false on relay error status', () async {
      await seedUser('u5');
      final failing = PushRelayService(
        firestore: fake,
        httpClient: MockClient((request) async {
          requests.add(request);
          return http.Response('unauthorized', 401);
        }),
        relayUrl: 'https://relay.example.com/push',
        relaySecret: 'wrong',
      );
      final ok = await failing.sendPush(
        targetUserId: 'u5',
        title: 'Ping',
        body: 'hi',
        type: 'ping',
      );
      expect(ok, isFalse);
      expect(requests, hasLength(1));
    });
  });
}
