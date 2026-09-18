import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/models/notification_model.dart';

void main() {
  test('resolves Amharic when locale is am', () {
    final n = AppNotification(
      id: '1',
      targetUserId: 'u1',
      title: 'Cofiz \u2192 Daily Prices',
      body: 'Hello',
      createdAt: DateTime.now(),
      titleAm: 'Cofiz \u2192 \u12d8\u1218\u1273\u12cb \u12cb\u130d\u1276',
      bodyAm: '\u1235\u120b\u121d',
    );
    expect(n.resolvedTitle('am'), n.titleAm);
    expect(n.resolvedBody('am'), n.bodyAm);
    expect(n.resolvedTitle('en'), n.title);
    expect(n.resolvedBody('en'), n.body);
  });

  test('falls back to English when Amharic missing', () {
    final n = AppNotification(
      id: '1',
      targetUserId: 'u1',
      title: 'T',
      body: 'B',
      createdAt: DateTime.now(),
    );
    expect(n.resolvedTitle('am'), 'T');
    expect(n.resolvedBody('am'), 'B');
  });

  test('round-trips title_am/body_am through Firestore', () {
    final n = AppNotification(
      id: '1',
      targetUserId: 'u1',
      title: 'T',
      body: 'B',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1000),
      titleAm: 'TA',
      bodyAm: 'BA',
    );
    final rt = AppNotification.fromFirestore(n.toFirestore(), '1');
    expect(rt.titleAm, 'TA');
    expect(rt.bodyAm, 'BA');
  });
}
