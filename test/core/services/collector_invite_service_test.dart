import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/services/collector_invite_service.dart';
import 'package:cofiz/core/utils/phone_utils.dart';

void main() {
  group('CollectorInviteService', () {
    test('createCollector writes users/{sha256(phone)} and links workers/{workerId}', () async {
      final fs = FakeFirebaseFirestore();
      await fs.collection('workers').doc('w1').set({'name': 'Abebe'});
      final svc = CollectorInviteService(firestore: fs);
      final r = await svc.createCollector(
        phoneE164: '+251911234567',
        displayName: 'Abebe',
        workerId: 'w1',
        adminUid: 'admin-uid',
      );
      expect(r.isCreated, isTrue);
      final userDoc = await fs.collection('users').doc(r.uid).get();
      expect(userDoc.data()!['phone'], '+251911234567');
      expect(userDoc.data()!['role'], 'worker');
      final workerDoc = await fs.collection('workers').doc('w1').get();
      expect(workerDoc.data()!['userId'], r.uid);
      expect(workerDoc.data()!['hasLoginAccess'], isTrue);
    });

    test('createCollector returns exists when users/{sha256(phone)} already present', () async {
      final fs = FakeFirebaseFirestore();
      final uid = sha256Hex('+251911234567');
      await fs.collection('users').doc(uid).set({'phone': '+251911234567', 'role': 'worker'});
      await fs.collection('workers').doc('w1').set({'name': 'Abebe'});
      final svc = CollectorInviteService(firestore: fs);
      final r = await svc.createCollector(
        phoneE164: '+251911234567',
        displayName: 'Abebe',
        workerId: 'w1',
        adminUid: 'admin-uid',
      );
      expect(r.isExists, isTrue);
      expect(r.uid, uid);
    });
  });
}
