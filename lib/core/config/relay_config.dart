import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class RelayConfig {
  static String _readEnv(String key) =>
      dotenv.isInitialized ? dotenv.env[key] ?? '' : '';
  static String get _envRelayUrl => _readEnv('RELAY_URL');
  static String get _envRelaySecret => _readEnv('RELAY_SECRET');
  static String get _envTelegramBotId => _readEnv('TELEGRAM_BOT_ID');

  static const String _fallbackRelayUrl = 'https://cofiz.natanim.dev';
  static const String _fallbackRelaySecret = '';
  static const String _fallbackTelegramBotId = '8777989279';

  static String _relayUrl = _envRelayUrl.isNotEmpty ? _envRelayUrl : _fallbackRelayUrl;
  static String _relaySecret = _envRelaySecret.isNotEmpty ? _envRelaySecret : _fallbackRelaySecret;
  static String _telegramBotId = _envTelegramBotId.isNotEmpty ? _envTelegramBotId : _fallbackTelegramBotId;
  static bool _initialized = false;

  static String get relayUrl => _relayUrl;
  static String get relaySecret => _relaySecret;
  static String get telegramBotId => _telegramBotId;

  static bool get isConfigured => relayUrl.isNotEmpty && relaySecret.isNotEmpty;

  static Future<void> init({
    FirebaseFirestore? firestore,
    bool force = false,
  }) async {
    if (_initialized && !force) return;
    try {
      final fs = firestore ?? FirebaseFirestore.instance;
      final doc = await fs
          .collection('settings')
          .doc('app')
          .get()
          .timeout(const Duration(seconds: 2));
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          final url = data['relayUrl'];
          final secret = data['relaySecret'];
          final tgId = data['telegramBotId'];
          if (url is String && url.isNotEmpty) _relayUrl = url;
          if (secret is String && secret.isNotEmpty) _relaySecret = secret;
          if (tgId is String && tgId.isNotEmpty) _telegramBotId = tgId;
          debugPrint(
              '[RelayConfig] loaded from Firestore: url=${_relayUrl.isNotEmpty ? "set" : "empty"} secret=${_relaySecret.isNotEmpty ? "set" : "empty"} telegramBotId=${_telegramBotId.isNotEmpty ? "set" : "empty"}');
        }
      } else {
        debugPrint('[RelayConfig] settings/app not found — using env fallback');
      }
    } catch (e) {
      debugPrint(
          '[RelayConfig] Firestore fetch failed, using env fallback: $e');
    }
    _initialized = true;
  }

  static Future<void> ensureInitialized({FirebaseFirestore? firestore}) async {
    if (!_initialized) await init(firestore: firestore);
  }

  @visibleForTesting
  static void setForTest({String? url, String? secret, String? telegramBotId}) {
    if (url != null) _relayUrl = url;
    if (secret != null) _relaySecret = secret;
    if (telegramBotId != null) _telegramBotId = telegramBotId;
    _initialized = true;
  }

  @visibleForTesting
  static void resetForTest() {
    _relayUrl = _envRelayUrl.isNotEmpty ? _envRelayUrl : _fallbackRelayUrl;
    _relaySecret = _envRelaySecret.isNotEmpty ? _envRelaySecret : _fallbackRelaySecret;
    _telegramBotId = _envTelegramBotId.isNotEmpty ? _envTelegramBotId : _fallbackTelegramBotId;
    _initialized = false;
  }

  @visibleForTesting
  static bool get isInitialized => _initialized;
}
