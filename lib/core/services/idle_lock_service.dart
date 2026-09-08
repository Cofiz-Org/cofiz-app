import 'dart:async';
import 'package:flutter/widgets.dart' hide LockState;
import '../providers/lock_state_provider.dart';

/// Watches for inactivity and app backgrounding to lock the app.
///
/// Use via `IdleLockService` singleton-ish: create in `StitchWorkerApp` and
/// call `attach()` in `initState`, `detach()` in `dispose`.
/// Interaction is reported via `onUserInteraction()` — wire it with a
/// top-level `Listener` + `NotificationListener` in the app's builder.
class IdleLockService with WidgetsBindingObserver {
  IdleLockService({required this.lockState, Duration? duration})
      : duration = duration ?? const Duration(minutes: 2) {
    assert(duration == null || duration > Duration.zero);
  }

  final LockStateProvider lockState;
  final Duration duration;

  Timer? _timer;
  bool _attached = false;

  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _attached = true;
    bump();
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _attached = false;
    _timer?.cancel();
  }

  void bump() {
    // Don't arm timer before lock state finished cold-start init, when not
    // unlocked, while force-sign-out is pending, or during cooldown.
    if (!lockState.isInitialized) return;
    if (lockState.state != PinLockState.unlocked) return;
    if (lockState.shouldForceSignOut) return;
    if (lockState.isInCooldown) return;
    _timer?.cancel();
    _timer = Timer(duration, () {
      if (lockState.state == PinLockState.unlocked &&
          !lockState.shouldForceSignOut) {
        lockState.lock();
      }
    });
  }

  void onUserInteraction() => bump();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _timer?.cancel();
        if (lockState.isInitialized &&
            lockState.state == PinLockState.unlocked) {
          lockState.markBackgrounded();
        }
        break;
      case AppLifecycleState.resumed:
        bump();
        break;
    }
  }
}
