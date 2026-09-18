import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cofiz/core/services/notification_trigger_service.dart';
import 'package:cofiz/core/services/push_relay_service.dart';

void main() {
  test('price set notifies all roles', () async {
    final firestore = FakeFirebaseFirestore();
    final requests = <http.Request>[];
    final relay = PushRelayService(
      firestore: firestore,
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{"sent":true}', 200);
      }),
      relayUrl: 'https://relay.example.com/push',
      relaySecret: 'secret123',
    );
    for (final entry in {'a1': 'admin', 'w1': 'worker', 'v1': 'viewer'}.entries) {
      await firestore.collection('users').doc(entry.key).set({
        'role': entry.value,
        'email': '${entry.key}@example.com',
      });
    }
    final svc =
        NotificationTriggerService(firestore: firestore, pushRelay: relay);
    await svc.notifyDailyPriceSet(
        setByName: 'Admin', prices: {'wet': 380, 'jenfel': 420});
    final docs = await firestore.collection('notifications').get();
    expect(docs.docs.length, 3);
    expect(requests.length, 3);
  });

  test('daily price body contains no emdash', () async {
    final firestore = FakeFirebaseFirestore();
    final relay = PushRelayService(
      firestore: firestore,
      httpClient: MockClient((request) async {
        expect(request.body.contains('\u2014'), isFalse);
        return http.Response('{"sent":true}', 200);
      }),
      relayUrl: 'https://relay.example.com/push',
      relaySecret: 'secret123',
    );
    await firestore.collection('users').doc('a1').set({'role': 'admin'});
    final svc =
        NotificationTriggerService(firestore: firestore, pushRelay: relay);
    await svc.notifyDailyPriceSet(setByName: 'Admin', prices: {'wet': 380});
    final docs = await firestore.collection('notifications').get();
    expect(docs.docs.length, 1);
    expect(docs.docs.first.data()['body'].contains('\u2014'), isFalse);
  });

  test('price change notifies in recipient locale (am user gets body_am)',
      () async {
    final firestore = FakeFirebaseFirestore();
    final relay = PushRelayService(
      firestore: firestore,
      httpClient: MockClient((request) async =>
          http.Response('{"sent":true}', 200)),
      relayUrl: 'https://relay.example.com/push',
      relaySecret: 'secret123',
    );
    await firestore
        .collection('users')
        .doc('a1')
        .set({'role': 'admin', 'language_code': 'am'});
    await firestore.collection('users').doc('w1').set({'role': 'worker'});
    final svc =
        NotificationTriggerService(firestore: firestore, pushRelay: relay);
    await svc.notifyDailyPriceSet(setByName: 'Admin', prices: {'wet': 380});
    final docs = await firestore.collection('notifications').get();
    final amDoc =
        docs.docs.firstWhere((d) => d.data()['targetUserId'] == 'a1');
    expect(amDoc.data()['body_am'], isNotNull);
    expect((amDoc.data()['body_am'] as String).contains('\u2014'), isFalse);
  });
}
