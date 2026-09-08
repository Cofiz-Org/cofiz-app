import 'dart:async';
import 'package:flutter/services.dart';

class TelegramNativeAuth {
  static const _channel = MethodChannel('com.cofiz.telegram_login');
  static final _coldStartController = StreamController<Map<String, String>>.broadcast();
  static Stream<Map<String, String>> get coldStartLogin => _coldStartController.stream;
  static bool _listenerRegistered = false;

  static void ensureListener() {
    if (_listenerRegistered) return;
    _listenerRegistered = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onTelegramLogin') {
        final data = Map<String, String>.from(
          (call.arguments as Map).map((k, v) => MapEntry(k.toString(), v.toString())),
        );
        _coldStartController.add(data);
      } else if (call.method == 'onTelegramLoginError') {
        _coldStartController.addError(call.arguments ?? 'unknown');
      }
      return null;
    });
  }

  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod<bool>('isAvailable') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, String>> login() async {
    ensureListener();
    final result = await _channel.invokeMapMethod<String, dynamic>('login');
    if (result == null) throw PlatformException(code: 'no_result', message: 'No result from native login');
    final idToken = result['idToken'] as String?;
    if (idToken == null || idToken.isEmpty) {
      throw PlatformException(code: 'no_id_token', message: 'Native login returned no idToken');
    }
    return {'idToken': idToken};
  }
}
