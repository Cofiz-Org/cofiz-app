import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String get defaultUpdateRepo {
  final fromEnv =
      dotenv.isInitialized ? dotenv.env['UPDATE_REPO'] ?? '' : '';
  return fromEnv.isNotEmpty ? fromEnv : 'cofiz-org/cofiz-dist';
}

const String _kApiBase = 'https://api.github.com';
const Duration _kCheckInterval = Duration(hours: 24);

String parseMinVersion(String body) {
  final m = RegExp(r'<!--\s*min-version:\s*([0-9][0-9A-Za-z.\-+]*)\s*-->').firstMatch(body);
  return m == null ? '' : m.group(1)!;
}

class ReleaseInfo {
  final String version;
  final String tag;
  final String notes;
  final String apkUrl;
  final String htmlUrl;
  final String minVersion;
  final DateTime? publishedAt;

  const ReleaseInfo({
    required this.version,
    required this.tag,
    required this.notes,
    required this.apkUrl,
    required this.htmlUrl,
    this.minVersion = '',
    this.publishedAt,
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'tag': tag,
        'notes': notes,
        'apkUrl': apkUrl,
        'htmlUrl': htmlUrl,
        'minVersion': minVersion,
        'publishedAt': publishedAt?.millisecondsSinceEpoch,
      };

  static ReleaseInfo? fromJson(Map<String, dynamic> json) {
    try {
      final version = json['version']?.toString() ?? '';
      final apkUrl = json['apkUrl']?.toString() ?? '';
      if (version.isEmpty || apkUrl.isEmpty) return null;
      final publishedMs = json['publishedAt'];
      final notes = json['notes']?.toString() ?? '';
      return ReleaseInfo(
        version: version,
        tag: json['tag']?.toString() ?? '',
        notes: notes,
        apkUrl: apkUrl,
        htmlUrl: json['htmlUrl']?.toString() ?? '',
        minVersion: json['minVersion']?.toString() ?? parseMinVersion(notes),
        publishedAt: publishedMs is int
            ? DateTime.fromMillisecondsSinceEpoch(publishedMs)
            : null,
      );
    } catch (_) {
      return null;
    }
  }
}

int compareVersions(String a, String b) {
  List<int> parts(String v) {
    var s = v.trim();
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    s = s.split('+').first.split('-').first;
    return s.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

class UpdateService {
  final http.Client _client;
  final SharedPreferences _prefs;
  final String repo;

  static const String _kLastCheckedKey = 'app_update_last_checked_ms';
  static const String _kCachedReleaseKey = 'app_update_cached_release';
  static const String _kDismissedKey = 'app_update_dismissed_versions';

  UpdateService({
    required SharedPreferences prefs,
    http.Client? client,
    String? repo,
  })  : _prefs = prefs,
        _client = client ?? http.Client(),
        repo = repo ?? defaultUpdateRepo;

  Uri get _latestReleaseUrl =>
      Uri.parse('$_kApiBase/repos/$repo/releases/latest');

  String? lastError;

  static String friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'The connection is too slow. Please retry.';
    }
    final text = error.toString().toLowerCase();
    bool hasAny(List<String> needles) =>
        needles.any((n) => text.contains(n));
    if (error is SocketException ||
        error is http.ClientException ||
        hasAny([
          'failed host lookup',
          'network is unreachable',
          'connection closed',
          'connection reset',
          'connection refused',
          'connection aborted',
          'broken pipe',
          'no internet',
          'offline',
        ])) {
      return 'No internet connection. Check your connection and retry.';
    }
    if (hasAny(['403', 'rate limit', 'too many requests'])) {
      return 'GitHub is busy right now. Please try again later.';
    }
    if (text.contains('404') || text.contains('not found')) {
      return 'Update not found on the server. Please try again later.';
    }
    if (hasAny(['500', '502', '503', 'server error'])) {
      return 'The server had a hiccup. Please try again.';
    }
    if (hasAny(['download incomplete', 'download failed'])) {
      return 'The download was interrupted. Please retry.';
    }
    if (text.contains('could not open installer') ||
        text.contains('could not open the installer')) {
      return 'Could not open the installer. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<ReleaseInfo?> checkForUpdates({
    required String currentVersion,
    bool force = false,
  }) async {
    lastError = null;
    if (!force && !_isStale()) {
      return _newerThanCurrent(_cachedRelease(), currentVersion);
    }
    Map<String, dynamic>? json;
    try {
      final res = await _client
          .get(
            _latestReleaseUrl,
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        lastError = 'GitHub API ${res.statusCode}';
        return _newerThanCurrent(_cachedRelease(), currentVersion);
      }
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (e) {
      lastError = e.toString();
      return _newerThanCurrent(_cachedRelease(), currentVersion);
    }
    await _prefs.setInt(
        _kLastCheckedKey, DateTime.now().millisecondsSinceEpoch);
    final release = _parseRelease(json);
    if (release != null) {
      await _prefs.setString(_kCachedReleaseKey, jsonEncode(release.toJson()));
    }
    return _newerThanCurrent(release ?? _cachedRelease(), currentVersion);
  }

  Future<void> downloadApk({
    required String url,
    required String destPath,
    void Function(double progress)? onProgress,
    required Future<bool> Function() isCancelled,
  }) async {
    final req = http.Request('GET', Uri.parse(url));
    req.headers['Accept'] = 'application/octet-stream';
    final res = await _client.send(req).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      throw StateError('Download failed: HTTP ${res.statusCode}');
    }
    final total = res.contentLength ?? -1;
    final sink = File(destPath).openWrite();
    var received = 0;
    try {
      await for (final chunk in res.stream) {
        if (await isCancelled()) {
          throw _DownloadCancelled();
        }
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) onProgress?.call(received / total);
      }
      await sink.close();
    } catch (_) {
      try {
        await sink.close();
      } catch (_) {}
      rethrow;
    }
    if (total > 0 && received != total) {
      throw StateError('Download incomplete ($received/$total bytes)');
    }
  }

  bool isDismissed(String version) =>
      _prefs.getStringList(_kDismissedKey)?.contains(version) ?? false;

  Future<void> dismissVersion(String version) async {
    final list = _prefs.getStringList(_kDismissedKey) ?? <String>[];
    if (!list.contains(version)) {
      list.add(version);
      await _prefs.setStringList(_kDismissedKey, list);
    }
  }

  bool _isStale() {
    final last = _prefs.getInt(_kLastCheckedKey);
    if (last == null) return true;
    return DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(last)) >=
        _kCheckInterval;
  }

  ReleaseInfo? _cachedRelease() {
    final raw = _prefs.getString(_kCachedReleaseKey);
    if (raw == null) return null;
    try {
      return ReleaseInfo.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  ReleaseInfo? _newerThanCurrent(ReleaseInfo? release, String current) {
    if (release == null) return null;
    if (compareVersions(release.version, current) <= 0) return null;
    if (isDismissed(release.version)) return null;
    return release;
  }

  ReleaseInfo? _parseRelease(Map<String, dynamic> json) {
    try {
      if (json['draft'] == true || json['prerelease'] == true) return null;
      final tag = json['tag_name']?.toString() ?? '';
      if (tag.isEmpty) return null;
      final assets = (json['assets'] as List?) ?? const [];
      String apkUrl = '';
      for (final a in assets) {
        final name = a is Map ? a['name']?.toString() ?? '' : '';
        final url = a is Map ? a['browser_download_url']?.toString() ?? '' : '';
        if (name.toLowerCase().endsWith('.apk') && url.isNotEmpty) {
          apkUrl = url;
          break;
        }
      }
      if (apkUrl.isEmpty) return null;
      final published = json['published_at']?.toString();
      final notes = json['body']?.toString() ?? '';
      return ReleaseInfo(
        version: tag,
        tag: tag,
        notes: notes,
        apkUrl: apkUrl,
        htmlUrl: json['html_url']?.toString() ?? '',
        minVersion: parseMinVersion(notes),
        publishedAt:
            published != null ? DateTime.tryParse(published) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class _DownloadCancelled implements Exception {
  @override
  String toString() => 'Download cancelled';
}

bool isDownloadCancelled(Object e) => e is _DownloadCancelled;
