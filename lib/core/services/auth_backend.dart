import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/relay_config.dart';

enum OtpProvider { telegram, whatsapp }

class AuthBackendException implements Exception {
  final int statusCode;
  final String errorCode;
  final String message;
  AuthBackendException(this.statusCode, this.errorCode, this.message);
  @override
  String toString() => 'AuthBackendException($statusCode/$errorCode): $message';
}

class RequestOtpResult {
  final String verificationId;
  final int expiresInSeconds;
  RequestOtpResult({required this.verificationId, required this.expiresInSeconds});
}

class VerifyOtpResult {
  final String customToken;
  final String uid;
  final bool isNewUser;
  VerifyOtpResult({required this.customToken, required this.uid, required this.isNewUser});
}

class AuthBackend {
  AuthBackend({
    required this.baseUrl,
    this.secret,
    http.Client? client,
  }) : _client = client ?? http.Client();
  final String baseUrl;
  final String? secret;
  final http.Client _client;

  String get _effectiveSecret => (secret != null && secret!.isNotEmpty) ? secret! : RelayConfig.relaySecret;
  String get _effectiveBaseUrl => baseUrl.isNotEmpty ? baseUrl : (RelayConfig.relayUrl.isNotEmpty ? RelayConfig.relayUrl : 'https://cofiz.natanim.dev');

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'content-type': 'application/json',
      if (_effectiveSecret.isNotEmpty) 'x-relay-secret': _effectiveSecret,
    };
  }

  Future<http.Response> _post(
      String path, Map<String, dynamic> body) async {
    try {
      return await _client.post(
        Uri.parse('$_effectiveBaseUrl$path'),
        headers: _headers(),
        body: jsonEncode(body),
      );
    } catch (_) {
      throw AuthBackendException(0, 'network_error', '');
    }
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw AuthBackendException(res.statusCode, 'bad_response', '');
    }
  }

  Future<RequestOtpResult> requestOtp({
    required String phone,
    required OtpProvider provider,
  }) async {
    final res = await _post('/auth/whatsapp/start', {
      'phone': phone,
      'provider': provider.name,
    });
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(res.statusCode, body['error']?.toString() ?? 'unknown', body['message']?.toString() ?? '');
    }
    return RequestOtpResult(
      verificationId: body['challengeId'] as String,
      expiresInSeconds: (body['expiresIn'] as num).toInt(),
    );
  }

  Future<RequestOtpResult> resendOtp({
    required String phone,
  }) async {
    final res =
        await _post('/auth/whatsapp/resend', {'phone': phone});
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(res.statusCode, body['error']?.toString() ?? 'unknown', body['message']?.toString() ?? '');
    }
    return RequestOtpResult(
      verificationId: body['challengeId'] as String,
      expiresInSeconds: (body['expiresIn'] as num).toInt(),
    );
  }

  Future<VerifyOtpResult> verifyOtp({
    required String phone,
    required OtpProvider provider,
    required String verificationId,
    required String code,
  }) async {
    final res = await _post('/auth/whatsapp/verify', {
      'phone': phone,
      'provider': provider.name,
      'challengeId': verificationId,
      'code': code,
    });
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(res.statusCode, body['error']?.toString() ?? 'unknown', body['message']?.toString() ?? '');
    }
    return VerifyOtpResult(
      customToken: body['customToken'] as String,
      uid: body['uid'] as String,
      isNewUser: body['isNewUser'] as bool,
    );
  }

  Future<VerifyOtpResult> authTelegram(Map<String, String> fields) async {
    final res = await _post('/auth/telegram', fields);
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(
        res.statusCode,
        body['error']?.toString() ?? 'unknown',
        body['message']?.toString() ?? '',
      );
    }
    return VerifyOtpResult(
      customToken: body['customToken'] as String,
      uid: body['uid'] as String,
      isNewUser: body['isNewUser'] as bool,
    );
  }

  Future<VerifyOtpResult> authTelegramNative(String idToken) async {
    final res =
        await _post('/auth/telegram/native', {'idToken': idToken});
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(
        res.statusCode,
        body['error']?.toString() ?? 'unknown',
        body['message']?.toString() ?? '',
      );
    }
    return VerifyOtpResult(
      customToken: body['customToken'] as String,
      uid: body['uid'] as String,
      isNewUser: body['isNewUser'] as bool,
    );
  }

  Future<void> requestEmailCode({required String uid}) async {
    final res = await _post('/auth/email/request', {'uid': uid});
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(
        res.statusCode,
        body['error']?.toString() ?? 'unknown',
        body['message']?.toString() ?? '',
      );
    }
  }

  Future<bool> verifyEmailCode(
      {required String uid, required String code}) async {
    final res = await _post('/auth/email/verify', {'uid': uid, 'code': code});
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(
        res.statusCode,
        body['error']?.toString() ?? 'unknown',
        body['message']?.toString() ?? '',
      );
    }
    return body['verified'] == true;
  }

  Future<void> register({
    required String phone,
    required String displayName,
    required String companyName,
    required String requestedRole,
    String? fcmToken,
  }) async {
    final res = await _post('/auth/register', {
      'phone': phone,
      'displayName': displayName,
      'companyName': companyName,
      'requestedRole': requestedRole,
      if (fcmToken != null && fcmToken.isNotEmpty) 'fcmToken': fcmToken,
    });
    final body = _decode(res);
    if (res.statusCode >= 400) {
      throw AuthBackendException(
        res.statusCode,
        body['error']?.toString() ?? 'unknown',
        body['message']?.toString() ?? '',
      );
    }
  }
}
