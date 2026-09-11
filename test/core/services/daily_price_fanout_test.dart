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
}
