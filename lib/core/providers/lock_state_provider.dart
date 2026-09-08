import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/pin_service.dart';

enum PinLockState { unlocked, locked, awaitingFirstSetup }

class LockStateProvider extends ChangeNotifier {
  LockStateProvider({required this.pinService, this.maxFailedAttempts = 5});
  final PinService pinService;
  final int maxFailedAttempts;

  PinLockState _state = PinLockState.unlocked;
  int _failedAttempts = 0;
  DateTime? _cooldownUntil;
  bool _initialized = false;
  String? _uid;

  PinLockState get state => _state;
  int get failedAttempts => _failedAttempts;
  DateTime? get cooldownUntil => _cooldownUntil;
  bool get isInitialized => _initialized;
  bool get isInCooldown => _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);
  Duration? get cooldownRemaining =>
      isInCooldown ? _cooldownUntil!.difference(DateTime.now()) : null;
  bool get shouldForceSignOut => _failedAttempts >= maxFailedAttempts;

  static String _prefsKey(String? uid, String field) =>
      uid == null || uid.isEmpty ? 'pin_lock_$field' : 'pin_lock_${uid}_$field';

  Future<void> initialize({String? uid}) async {
    if (_initialized && _state == PinLockState.locked && _uid == uid) return;
    _uid = uid;
    final hasPin = await pinService.hasPin(uid: uid);
    if (!hasPin) {
      _state = PinLockState.awaitingFirstSetup;
      _failedAttempts = 0;
      _cooldownUntil = null;
    } else {
      await _restorePersistedState(uid);
      if (_state != PinLockState.locked) {
        _state = PinLockState.locked;
        await _persistLocked(uid, true);
      }
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> _restorePersistedState(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _failedAttempts = prefs.getInt(_prefsKey(uid, 'failed')) ?? 0;
      final cooldownMs = prefs.getInt(_prefsKey(uid, 'cooldown_ms'));
      _cooldownUntil = cooldownMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(cooldownMs);
      if (_cooldownUntil != null &&
          !DateTime.now().isBefore(_cooldownUntil!)) {
        _cooldownUntil = null;
        if (_failedAttempts >= maxFailedAttempts) _failedAttempts = maxFailedAttempts;
      }
      final wasLocked = prefs.getBool(_prefsKey(uid, 'locked')) ?? false;
      _state = wasLocked ? PinLockState.locked : PinLockState.locked;
    } catch (_) {
      _state = PinLockState.locked;
    }
  }

  Future<void> _persistLocked(String? uid, bool locked) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefsKey(uid, 'locked'), locked);
      await prefs.setInt(_prefsKey(uid, 'last_paused_ms'),
          DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  Future<void> _persistAttempts(String? uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsKey(uid, 'failed'), _failedAttempts);
      if (_cooldownUntil != null) {
        await prefs.setInt(_prefsKey(uid, 'cooldown_ms'),
            _cooldownUntil!.millisecondsSinceEpoch);
      } else {
        await prefs.remove(_prefsKey(uid, 'cooldown_ms'));
      }
    } catch (_) {}
  }

  Future<void> lock({String? uid}) async {
    _state = PinLockState.locked;
    _failedAttempts = 0;
    _cooldownUntil = null;
    await _persistLocked(uid ?? _uid, true);
    await _persistAttempts(uid ?? _uid);
    notifyListeners();
  }

  Future<void> markBackgrounded({String? uid}) async {
    if (_state != PinLockState.unlocked) return;
    await lock(uid: uid ?? _uid);
  }

  Future<bool> attemptUnlock(String pin, {String? uid}) async {
    if (isInCooldown) return false;
    final key = uid ?? _uid;
    final ok = await pinService.verifyPin(pin, uid: key);
    if (ok) {
      _state = PinLockState.unlocked;
      _failedAttempts = 0;
      _cooldownUntil = null;
      await _persistLocked(key, false);
      await _persistAttempts(key);
    } else {
      _failedAttempts += 1;
      // Exponential cooldown: 10s after 3rd, 30s after 4th, force sign-out at 5.
      if (_failedAttempts == 3) {
        _cooldownUntil = DateTime.now().add(const Duration(seconds: 10));
      } else if (_failedAttempts == 4) {
        _cooldownUntil = DateTime.now().add(const Duration(seconds: 30));
      }
      await _persistLocked(key, true);
      await _persistAttempts(key);
    }
    notifyListeners();
    return ok;
  }

  Future<void> reset({String? uid}) async {
    final key = uid ?? _uid;
    await pinService.clearPin(uid: key);
    _state = PinLockState.awaitingFirstSetup;
    _failedAttempts = 0;
    _cooldownUntil = null;
    _initialized = true;
    await _persistLocked(key, false);
    await _persistAttempts(key);
    notifyListeners();
  }

  Future<void> onSignedOut({String? uid}) async {
    final key = uid ?? _uid;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey(key, 'locked'));
      await prefs.remove(_prefsKey(key, 'failed'));
      await prefs.remove(_prefsKey(key, 'cooldown_ms'));
      await prefs.remove(_prefsKey(key, 'last_paused_ms'));
    } catch (_) {}
    _state = PinLockState.unlocked;
    _failedAttempts = 0;
    _cooldownUntil = null;
    _initialized = false;
    _uid = null;
    notifyListeners();
  }

  Future<void> clearCooldown({String? uid}) async {
    _cooldownUntil = null;
    await _persistAttempts(uid ?? _uid);
    notifyListeners();
  }

  /// Unlock via biometric — trusted path, clears cooldown and unlocks.
  /// Returns false when no PIN exists so callers can hide the biometric
  /// affordance instead of bypassing the lock.
  Future<bool> unlockWithBiometric({String? uid}) async {
    final key = uid ?? _uid;
    if (!await pinService.hasPin(uid: key)) return false;
    _state = PinLockState.unlocked;
    _failedAttempts = 0;
    _cooldownUntil = null;
    await _persistLocked(key, false);
    await _persistAttempts(key);
    notifyListeners();
    return true;
  }
}
