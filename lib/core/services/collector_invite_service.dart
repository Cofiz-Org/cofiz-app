import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/phone_utils.dart';

sealed class InviteResult {
  const InviteResult();
  bool get isCreated => this is InviteCreated;
  bool get isExists => this is InviteExists;
  String get uid => switch (this) {
        InviteCreated(:final uid) => uid,
        InviteExists(:final uid) => uid,
      };
}

class InviteCreated extends InviteResult {
  const InviteCreated(this.uid);
  @override
  final String uid;
}

class InviteExists extends InviteResult {
  const InviteExists({required this.uid, required this.existing});
  @override
  final String uid;
  final Map<String, dynamic> existing;
}

class CollectorInviteService {
  CollectorInviteService({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _fs;

  Future<InviteResult> createCollector({
    required String phoneE164,
    required String displayName,
    required String workerId,
    required String adminUid,
  }) async {
    final uid = sha256Hex(phoneE164);
    final userRef = _fs.collection('users').doc(uid);
    final snap = await userRef.get();
    if (snap.exists) {
      return InviteExists(uid: uid, existing: Map<String, dynamic>.from(snap.data() ?? {}));
    }
    await userRef.set({
      'uid': uid,
      'phone': phoneE164,
      'role': 'worker',
      'displayName': displayName,
      'workerId': workerId,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': adminUid,
      'isActive': true,
      'emailVerified': false,
    });
    await _fs.collection('workers').doc(workerId).update({
      'userId': uid,
      'hasLoginAccess': true,
    });
    return InviteCreated(uid);
  }

  Future<void> revokeAccess({required String workerId, required String userId}) async {
    await _fs.collection('users').doc(userId).delete();
    await _fs.collection('workers').doc(workerId).update({
      'userId': FieldValue.delete(),
      'hasLoginAccess': false,
    });
  }
}
