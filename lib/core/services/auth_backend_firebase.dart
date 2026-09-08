import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthBackendFirebase {
  AuthBackendFirebase({FirebaseAuth? auth}) : _auth = auth;
  final FirebaseAuth? _auth;
  FirebaseAuth get _resolved => _auth ?? FirebaseAuth.instance;

  static const String _loginTimestampKey = 'login_timestamp';

  Future<UserCredential> signInWithCustomToken(String token) async {
    final cred = await _resolved.signInWithCustomToken(token);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_loginTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
    return cred;
  }

  Future<void> signOut() => _resolved.signOut();

  Stream<User?> get authStateChanges => _resolved.authStateChanges();
}
