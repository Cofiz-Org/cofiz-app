import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cofiz/core/models/notification_model.dart';
import 'package:cofiz/core/services/notification_trigger_service.dart';
import 'package:cofiz/core/services/push_relay_service.dart';

void main() {
  late FakeFirebaseFirestore firestore;
  late List<http.Request> relayRequests;

  PushRelayService mockRelay() => PushRelayService(
        firestore: firestore,
        httpClient: MockClient((request) async {
          relayRequests.add(request);
          return http.Response('{"sent":true}', 200);
        }),
        relayUrl: 'https://relay.example.com/push',
        relaySecret: 'secret123',
      );

  /// Seed a user doc and fire a money-distributed notification at them.
  Future<void> triggerFor(
    String uid, {
    bool? emailVerified,
    bool? emailNotificationsEnabled,
    bool? pushNotificationsEnabled,
  }) async {
    await firestore.collection('users').doc(uid).set({
      'email': '$uid@example.com',
      if (emailVerified != null) 'emailVerified': emailVerified,
      if (emailNotificationsEnabled != null)
        'emailNotificationsEnabled': emailNotificationsEnabled,
      if (pushNotificationsEnabled != null)
        'pushNotificationsEnabled': pushNotificationsEnabled,
    });
    final svc = NotificationTriggerService(
        firestore: firestore, pushRelay: mockRelay());
    await svc.notifyMoneyDistributed(
      workerId: 'w1',
      workerUserId: uid,
      workerName: 'Worker',
      amount: 100,
      adminName: 'Admin',
    );
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
    relayRequests = [];
  });

  test('notification doc is always created (push path unchanged)', () async {
    await triggerFor('u1', emailVerified: false);
    final notifications = await firestore.collection('notifications').get();
    expect(notifications.docs.length, 1);
    expect(notifications.docs.first.data()['type'],
        NotificationType.moneyDistributed.name);
  });

  test('no mail queued when user is not verified', () async {
    await triggerFor('u2',
        emailVerified: false, emailNotificationsEnabled: true);
    final mail = await firestore.collection('mail').get();
    expect(mail.docs, isEmpty);
  });

  test('mail queued when user is verified and opted in', () async {
    await triggerFor('u3',
        emailVerified: true, emailNotificationsEnabled: true);
    final mail = await firestore.collection('mail').get();
    expect(mail.docs.length, 1);
    final data = mail.docs.first.data();
    expect(data['to'], 'u3@example.com');
    expect((data['template'] as Map)['name'], 'notification');
  });

  test('no mail queued when user is verified but opted out', () async {
    await triggerFor('u4',
        emailVerified: true, emailNotificationsEnabled: false);
    final mail = await firestore.collection('mail').get();
    expect(mail.docs, isEmpty);
  });

  test('no mail queued when user has no preference flags yet', () async {
    // Fresh users have neither flag; default must be no email.
    await triggerFor('u5');
    final mail = await firestore.collection('mail').get();
    expect(mail.docs, isEmpty);
  });

  test('relay push fires for the target user', () async {
    await triggerFor('u6', emailVerified: false);
    expect(relayRequests, hasLength(1));
  });

  test('relay push skipped when user opted out of push', () async {
    await triggerFor('u7', pushNotificationsEnabled: false);
    final notifications = await firestore.collection('notifications').get();
    expect(notifications.docs.length, 1);
    expect(relayRequests, isEmpty);
  });

  test('company debt notification names the creditor and link', () async {
    await firestore.collection('users').doc('admin1').set({
      'role': 'admin',
      'email': 'admin1@example.com',
    });
    final svc = NotificationTriggerService(
        firestore: firestore, pushRelay: mockRelay());
    await svc.notifyDebtRecorded(
      collectorId: 'company',
      collectorName: 'Company',
      forgivenAmount: 500,
      totalAmount: 800,
      linkedName: 'Transport',
      source: 'expense',
      creditorName: 'Geda',
    );
    final notifications = await firestore.collection('notifications').get();
    expect(notifications.docs.length, 1);
    final body = notifications.docs.first.data()['body'] as String;
    expect(body.contains('You owe Geda'), isTrue);
    expect(body.contains('Transport'), isTrue);
    expect(body.contains('Collector'), isFalse);
  });

  test('collector debt notification falls back to collector as creditor', () async {
    await firestore.collection('users').doc('admin1').set({
      'role': 'admin',
      'email': 'admin1@example.com',
    });
    final svc = NotificationTriggerService(
        firestore: firestore, pushRelay: mockRelay());
    await svc.notifyDebtRecorded(
      collectorId: 'c1',
      collectorName: 'Alice',
      forgivenAmount: 600,
      totalAmount: 1000,
    );
    final notifications = await firestore.collection('notifications').get();
    expect(notifications.docs.length, 1);
    final body = notifications.docs.first.data()['body'] as String;
    expect(body.contains('You owe Alice'), isTrue);
  });

  // --- Task 1: ping-only — admin echo removed (RED phase) ---
  test('purchase does not notify admins (ping-only) — low balance', () async {
    // Seed an admin so _notifyAllAdmins would have had a target before the fix.
    await firestore.collection('users').doc('admin1').set({
      'role': 'admin',
      'email': 'admin1@example.com',
    });
    final svc = NotificationTriggerService(firestore: firestore);
    await svc.checkLowBalance(
      workerId: 'w1',
      workerUserId: 'u1',
      workerName: 'A',
      newBalance: 100,
    );
    final notifications = await firestore.collection('notifications').get();
    expect(notifications.docs, isEmpty,
        reason: 'admin echo removed: lowBalance must not create notifications');
    final mail = await firestore.collection('mail').get();
    expect(mail.docs, isEmpty);
  });

  test('collector user gets a bell doc when their debt is recorded', () async {
    await firestore.collection('users').doc('admin1').set({
      'role': 'admin',
      'email': 'admin1@example.com',
    });
    await firestore.collection('users').doc('user-c1').set({
      'role': 'worker',
      'email': 'user-c1@example.com',
    });
    await firestore.collection('workers').doc('c1').set({
      'name': 'Collector One',
      'userId': 'user-c1',
    });
    final svc = NotificationTriggerService(
        firestore: firestore, pushRelay: mockRelay());
    await svc.notifyDebtRecorded(
      collectorId: 'c1',
      collectorName: 'Collector One',
      forgivenAmount: 600,
      totalAmount: 1000,
    );
    final snap = await firestore
        .collection('notifications')
        .where('targetUserId', isEqualTo: 'user-c1')
        .get();
    expect(snap.docs, hasLength(1));
    expect(snap.docs.first.data()['type'], 'debtRecorded');
  });

  test('large purchase does not notify admins (ping-only)', () async {
    await firestore.collection('users').doc('admin1').set({
      'role': 'admin',
      'email': 'admin1@example.com',
    });
    await firestore.collection('users').doc('admin2').set({
      'role': 'admin',
      'email': 'admin2@example.com',
    });
    final svc = NotificationTriggerService(firestore: firestore);
    await svc.checkLargePurchase(
      workerId: 'w1',
      workerName: 'A',
      amount: 15000,
      coffeeType: 'Yirgacheffe',
      weight: 10,
    );
    final notifications = await firestore.collection('notifications').get();
    expect(notifications.docs, isEmpty,
        reason: 'admin echo removed: largePurchase must not create notifications');
    final mail = await firestore.collection('mail').get();
    expect(mail.docs, isEmpty);
  });
}
