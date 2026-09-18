import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/providers/notification_provider.dart';

void main() {
  test('markAsRead flips local state instantly', () async {
    final firestore = FakeFirebaseFirestore();
    final ref = await firestore.collection('notifications').add({
      'targetUserId': 'u1',
      'title': 'T',
      'body': 'B',
      'type': 'info',
      'isRead': false,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    final provider = NotificationProvider(firestore: firestore);
    provider.init('u1');
    await Future.delayed(const Duration(milliseconds: 200));
    expect(provider.unreadCount, 1);
    final future = provider.markAsRead(ref.id);
    // Optimistic: local state flips before the write completes.
    expect(
        provider.notifications.firstWhere((n) => n.id == ref.id).isRead,
        isTrue);
    expect(provider.unreadCount, 0);
    await future;
    expect(
        provider.notifications.firstWhere((n) => n.id == ref.id).isRead,
        isTrue);
  });
}
