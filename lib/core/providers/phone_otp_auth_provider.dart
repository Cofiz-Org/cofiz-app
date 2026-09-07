import 'package:flutter/foundation.dart';
import '../../l10n/app_localizations.dart';
import '../services/auth_backend.dart';
import '../services/fcm_service.dart';
import '../services/auth_backend_firebase.dart';
import '../services/pin_service.dart';

enum OtpAuthState {
  unauthenticated,
  awaitingCode,
  verifying,
  authenticated,
  error,
  awaitingTelegramReturn,
}

class PhoneOtpAuthProvider extends ChangeNotifier {
  PhoneOtpAuthProvider({required this.backend, AuthBackendFirebase? firebaseAuth, PinService? pinService})
      : _firebaseAuth = firebaseAuth,
        _pinService = pinService;
  final AuthBackend backend;
  final AuthBackendFirebase? _firebaseAuth;
  final PinService? _pinService;

  OtpAuthState _state = OtpAuthState.unauthenticated;
  String? _phone;
  OtpProvider? _provider;
  String? _verificationId;
  String? _uid;
  String? _lastErrorCode;
  String? _lastErrorMessage;

  OtpAuthState get state => _state;
  String? get phone => _phone;
  OtpProvider? get provider => _provider;
  String? get verificationId => _verificationId;
  String? get uid => _uid;
  bool get isAuthenticated => _state == OtpAuthState.authenticated;
  String? get lastErrorCode => _lastErrorCode;
  String? get lastErrorMessage => _lastErrorMessage;

  String authErrorMessage(AppLocalizations? l10n, {String? fallback}) {
    if (_lastErrorCode == 'network_error') {
      return l10n?.networkError ??
          'No internet connection. Check your connection and try again.';
    }
    if (_lastErrorCode == 'bad_response') {
      return l10n?.serverError ?? 'Server error. Please try again later.';
    }
    if (_lastErrorMessage != null && _lastErrorMessage!.isNotEmpty) {
      return _lastErrorMessage!;
    }
    return _lastErrorCode ?? fallback ?? 'Something went wrong';
  }

  Future<void> requestOtp({required String phone, required OtpProvider provider}) async {
    _phone = phone;
    _provider = provider;
    _state = OtpAuthState.unauthenticated;
    notifyListeners();
    try {
      final r = await backend.requestOtp(phone: phone, provider: provider);
      _verificationId = r.verificationId;
      _state = OtpAuthState.awaitingCode;
    } on AuthBackendException catch (e) {
      _lastErrorCode = e.errorCode;
      _lastErrorMessage = e.message;
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }

  Future<void> resendOtp() async {
    if (_phone == null) return;
    _state = OtpAuthState.unauthenticated;
    notifyListeners();
    try {
      final r = await backend.resendOtp(phone: _phone!);
      _verificationId = r.verificationId;
      _state = OtpAuthState.awaitingCode;
    } on AuthBackendException catch (e) {
      _lastErrorCode = e.errorCode;
      _lastErrorMessage = e.message;
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }

  Future<void> verifyOtp({required String code}) async {
    if (_phone == null || _provider == null || _verificationId == null) {
      _state = OtpAuthState.error;
      _lastErrorMessage = 'No verification in progress';
      notifyListeners();
      return;
    }
    _state = OtpAuthState.verifying;
    notifyListeners();
    try {
      final r = await backend.verifyOtp(
        phone: _phone!,
        provider: _provider!,
        verificationId: _verificationId!,
        code: code,
      );
      _uid = r.uid;
      if (_firebaseAuth != null) {
        try {
          await _firebaseAuth.signInWithCustomToken(r.customToken);
        } catch (e) {
          _lastErrorCode = 'firebase_signin_failed';
          _lastErrorMessage = e.toString();
          _state = OtpAuthState.error;
          notifyListeners();
          return;
        }
      }
      _state = OtpAuthState.authenticated;
    } on AuthBackendException catch (e) {
      _lastErrorCode = e.errorCode;
      _lastErrorMessage = e.message;
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }

  Future<void> completeTelegramLogin({required Map<String, String> fields}) async {
    _state = OtpAuthState.verifying;
    _lastErrorCode = null;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final r = await backend.authTelegram(fields);
      _uid = r.uid;
      if (_firebaseAuth != null) {
        try {
          await _firebaseAuth.signInWithCustomToken(r.customToken);
        } catch (e) {
          _lastErrorCode = 'firebase_signin_failed';
          _lastErrorMessage = e.toString();
          _state = OtpAuthState.error;
          notifyListeners();
          return;
        }
      }
      _state = OtpAuthState.authenticated;
    } on AuthBackendException catch (e) {
      _lastErrorCode = e.errorCode;
      _lastErrorMessage = e.message;
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }

  Future<void> completeTelegramNative({required String idToken}) async {
    _state = OtpAuthState.verifying;
    _lastErrorCode = null;
    _lastErrorMessage = null;
    notifyListeners();
    try {
      final r = await backend.authTelegramNative(idToken);
      _uid = r.uid;
      if (_firebaseAuth != null) {
        try {
          await _firebaseAuth.signInWithCustomToken(r.customToken);
        } catch (e) {
          _lastErrorCode = 'firebase_signin_failed';
          _lastErrorMessage = e.toString();
          _state = OtpAuthState.error;
          notifyListeners();
          return;
        }
      }
      _state = OtpAuthState.authenticated;
    } on AuthBackendException catch (e) {
      _lastErrorCode = e.errorCode;
      _lastErrorMessage = e.message;
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }

  Future<void> completeWithCustomToken({required String customToken, required String uid}) async {
    _state = OtpAuthState.verifying;
    notifyListeners();
    try {
      if (_firebaseAuth != null) {
        await _firebaseAuth.signInWithCustomToken(customToken);
      }
      _uid = uid;
      _state = OtpAuthState.authenticated;
    } catch (e) {
      _lastErrorCode = 'firebase_signin_failed';
      _lastErrorMessage = e.toString();
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    final uidToClear = _uid;
    final fb = _firebaseAuth;
    if (fb != null) {
      try {
        await fb.signOut();
      } catch (_) {}
    }
    try {
      if (uidToClear != null && uidToClear.isNotEmpty) {
        await _pinService?.clearPin(uid: uidToClear);
      }
      await _pinService?.clearAll();
    } catch (_) {}
    _state = OtpAuthState.unauthenticated;
    _phone = null;
    _provider = null;
    _verificationId = null;
    _uid = null;
    _lastErrorCode = null;
    _lastErrorMessage = null;
    notifyListeners();
  }

  String? _resolveFcmToken(String? explicit) {
    if (explicit != null && explicit.isNotEmpty) return explicit;
    try {
      return FCMService().currentToken;
    } catch (_) {
      return null;
    }
  }

  Future<void> register({
    required String phone,
    required String displayName,
    required String companyName,
    required String requestedRole,
    String? fcmToken,
  }) async {
    _state = OtpAuthState.verifying;
    notifyListeners();
    try {
      await backend.register(
        phone: phone,
        displayName: displayName,
        companyName: companyName,
        requestedRole: requestedRole,
        fcmToken: _resolveFcmToken(fcmToken),
      );
      _state = OtpAuthState.unauthenticated;
    } catch (e) {
      _lastErrorCode = 'register_failed';
      _lastErrorMessage = e.toString();
      _state = OtpAuthState.error;
    }
    notifyListeners();
  }
}
