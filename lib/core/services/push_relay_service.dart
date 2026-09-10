import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/relay_config.dart';

/// Shared Cloudflare relay fan-out for FCM pushes.
///
/// The relay (POST [RelayConfig.relayUrl] with `X-Relay-Secret`) looks up
/// `users/{uid}.fcmToken` via Firestore REST and sends through FCM HTTP v1.
/// All calls are best-effort and never throw: push must not fail the
/// Firestore write it accompanies.
class PushRelayService {
  PushRelayService({
    FirebaseFirestore? firestore,
    http.Client? httpClient,
    String? relayUrl,
    String? relaySecret,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _httpClient = httpClient ?? http.Client(),
        _relayUrlOverride = relayUrl,
        _relaySecretOverride = relaySecret;

  final FirebaseFirestore _firestore;
  final http.Client _httpClient;
  final String? _relayUrlOverride;
  final String? _relaySecretOverride;

  static final PushRelayService _shared = PushRelayService._internal();
  PushRelayService._internal()
      : _firestore = FirebaseFirestore.instance,
        _httpClient = http.Client(),
        _relayUrlOverride = null,
        _relaySecretOverride = null;
  static PushRelayService get shared => _shared;

  /// True when the target user has NOT opted out of push. Absent flag
  /// defaults to opted-in so existing users keep receiving pushes.
  Future<bool> isPushEnabled(String targetUserId) async {
    try {
      final doc =
          await _firestore.collection('users').doc(targetUserId).get();
      final data = doc.data();
      if (data == null) return true;
      return data['pushNotificationsEnabled'] != false;
    } catch (_) {
      return true;
    }
  }

  /// Sends a push unless the target opted out. Returns true when the relay
  /// accepted it. Never throws.
  Future<bool> sendPush({
    required String targetUserId,
    required String title,
    required String body,
    required String type,
    Map<String, String>? data,
  }) async {
    String relayUrl = _relayUrlOverride ?? RelayConfig.relayUrl;
    String relaySecret = _relaySecretOverride ?? RelayConfig.relaySecret;
    if (_relayUrlOverride == null || _relaySecretOverride == null) {
      try {
        await RelayConfig.ensureInitialized(firestore: _firestore);
        relayUrl = _relayUrlOverride ?? RelayConfig.relayUrl;
        relaySecret = _relaySecretOverride ?? RelayConfig.relaySecret;
      } catch (_) {}
    }
    if (relayUrl.isEmpty || relaySecret.isEmpty) {
      debugPrint('[Relay] SKIPPED - not configured. '
          'Set settings/app relayUrl/relaySecret.');
      return false;
    }
    try {
      if (!await isPushEnabled(targetUserId)) {
        debugPrint('[Relay] SKIPPED - $targetUserId opted out of push');
        return false;
      }
      final payload = <String, dynamic>{
        'targetUserId': targetUserId,
        'title': title,
        'body': body,
        'type': type,
      };
      if (data != null && data.isNotEmpty) payload['data'] = data;
      final res = await _httpClient.post(
        Uri.parse(relayUrl),
        headers: {
          'Content-Type': 'application/json',
          'X-Relay-Secret': relaySecret,
        },
        body: jsonEncode(payload),
      );
      debugPrint('[Relay] $type -> $targetUserId: ${res.statusCode}');
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (e) {
      debugPrint('[Relay] push failed: $e');
      return false;
    }
  }
}
