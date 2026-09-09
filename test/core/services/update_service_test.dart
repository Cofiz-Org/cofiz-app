import 'dart:convert';
import 'dart:io';

import 'package:cofiz/core/services/update_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> releaseJson({
  String tag = 'v1.2.0',
  bool prerelease = false,
  bool draft = false,
  bool withApk = true,
  String body = 'Bug fixes',
}) {
  return {
    'tag_name': tag,
    'prerelease': prerelease,
    'draft': draft,
    'body': body,
    'html_url': 'https://github.com/o/r/releases/tag/$tag',
    'published_at': '2026-09-01T00:00:00Z',
    'assets': [
      if (withApk)
        {
          'name': 'cofiz-$tag.apk',
          'browser_download_url': 'https://example.com/cofiz.apk',
        },
      {'name': 'notes.txt', 'browser_download_url': 'https://example.com/n.txt'},
    ],
  };
}

class FakeUpdateHttp extends http.BaseClient {
  int latestCalls = 0;
  Map<String, dynamic>? releaseJson;
  int latestStatus = 200;
  bool throwOnLatest = false;
  List<int> apkBytes = utf8.encode('fake-apk-bytes');
  int apkStatus = 200;
  int? apkContentLengthOverride;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/releases/latest')) {
      latestCalls++;
      if (throwOnLatest) throw const SocketException('offline');
      final body = utf8.encode(jsonEncode(releaseJson ?? {}));
      return http.StreamedResponse(Stream.value(body), latestStatus);
    }
    final len = apkContentLengthOverride ?? apkBytes.length;
    return http.StreamedResponse(
      Stream.value(apkBytes),
      apkStatus,
      contentLength: len,
    );
  }
}

Future<UpdateService> makeService(FakeUpdateHttp http,
    {String repo = 'o/r'}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return UpdateService(prefs: prefs, client: http, repo: repo);
}

void main() {
  group('compareVersions', () {
    test('orders dotted versions', () {
      expect(compareVersions('1.2.0', '1.10.0'), lessThan(0));
      expect(compareVersions('2.0.0', '1.9.9'), greaterThan(0));
      expect(compareVersions('1.2.3', '1.2.3'), 0);
    });
    test('strips v prefix, build metadata and suffixes', () {
      expect(compareVersions('v1.2.0', '1.2.0'), 0);
      expect(compareVersions('1.2.0+5', '1.2.0+9'), 0);
      expect(compareVersions('1.2', '1.2.0'), 0);
      expect(compareVersions('v1.1.9', '1.2.0'), lessThan(0));
    });
  });

  group('checkForUpdates', () {
    test('returns release when newer', () async {
      final http = FakeUpdateHttp()..releaseJson = releaseJson(tag: 'v1.2.0');
      final svc = await makeService(http);
      final r = await svc.checkForUpdates(currentVersion: '1.1.9');
      expect(r, isNotNull);
      expect(r!.version, 'v1.2.0');
      expect(r.apkUrl, 'https://example.com/cofiz.apk');
      expect(r.notes, 'Bug fixes');
    });

    test('returns null when same or older', () async {
      final http = FakeUpdateHttp()..releaseJson = releaseJson(tag: 'v1.2.0');
      final svc = await makeService(http);
      expect(await svc.checkForUpdates(currentVersion: '1.2.0'), isNull);
      expect(
          await svc.checkForUpdates(currentVersion: '2.0.0', force: true),
          isNull);
    });

    test('ignores prerelease, draft and asset-less releases', () async {
      for (final j in [
        releaseJson(tag: 'v9.9.9', prerelease: true),
        releaseJson(tag: 'v9.9.9', draft: true),
        releaseJson(tag: 'v9.9.9', withApk: false),
      ]) {
        final http = FakeUpdateHttp()..releaseJson = j;
        final svc = await makeService(http);
        expect(await svc.checkForUpdates(currentVersion: '1.0.0'), isNull,
            reason: jsonEncode(j));
      }
    });

    test('network failure is silent and keeps cache', () async {
      final http = FakeUpdateHttp()..releaseJson = releaseJson(tag: 'v1.2.0');
      final svc = await makeService(http);
      final first = await svc.checkForUpdates(currentVersion: '1.1.9');
      expect(first, isNotNull);
      http.throwOnLatest = true;
      final second = await svc.checkForUpdates(
          currentVersion: '1.1.9', force: true);
      expect(second, isNotNull);
      expect(svc.lastError, isNotNull);
    });

    test('non-200 is silent', () async {
      final http = FakeUpdateHttp()
        ..releaseJson = releaseJson()
        ..latestStatus = 403;
      final svc = await makeService(http);
      expect(await svc.checkForUpdates(currentVersion: '1.0.0'), isNull);
      expect(svc.lastError, contains('403'));
    });

    test('24h cache gates network, force bypasses', () async {
      final http = FakeUpdateHttp()..releaseJson = releaseJson(tag: 'v1.2.0');
      final svc = await makeService(http);
      await svc.checkForUpdates(currentVersion: '1.2.0');
      await svc.checkForUpdates(currentVersion: '1.2.0');
      expect(http.latestCalls, 1);
      await svc.checkForUpdates(currentVersion: '1.2.0', force: true);
      expect(http.latestCalls, 2);
    });

    test('dismissed version stays quiet', () async {
      final http = FakeUpdateHttp()..releaseJson = releaseJson(tag: 'v1.2.0');
      final svc = await makeService(http);
      await svc.dismissVersion('v1.2.0');
      expect(await svc.checkForUpdates(currentVersion: '1.1.9'), isNull);
    });
  });

  group('downloadApk', () {
    test('writes bytes and reports full progress', () async {
      final http = FakeUpdateHttp();
      final svc = await makeService(http);
      final dir = await Directory.systemTemp.createTemp('upd');
      final dest = '${dir.path}/a.apk';
      var last = 0.0;
      await svc.downloadApk(
        url: 'https://example.com/cofiz.apk',
        destPath: dest,
        onProgress: (p) => last = p,
        isCancelled: () async => false,
      );
      expect(await File(dest).readAsString(), 'fake-apk-bytes');
      expect(last, 1.0);
    });

    test('cancel aborts the download', () async {
      final http = FakeUpdateHttp();
      final svc = await makeService(http);
      final dir = await Directory.systemTemp.createTemp('upd');
      Object? err;
      try {
        await svc.downloadApk(
          url: 'https://example.com/cofiz.apk',
          destPath: '${dir.path}/a.apk',
          isCancelled: () async => true,
        );
      } catch (e) {
        err = e;
      }
      expect(err, isNotNull);
      expect(isDownloadCancelled(err!), isTrue);
    });

    test('short body throws incomplete', () async {
      final http = FakeUpdateHttp()..apkContentLengthOverride = 9999;
      final svc = await makeService(http);
      final dir = await Directory.systemTemp.createTemp('upd');
      expect(
        () => svc.downloadApk(
          url: 'https://example.com/cofiz.apk',
          destPath: '${dir.path}/a.apk',
          isCancelled: () async => false,
        ),
        throwsStateError,
      );
    });

    test('http error throws', () async {
      final http = FakeUpdateHttp()..apkStatus = 404;
      final svc = await makeService(http);
      final dir = await Directory.systemTemp.createTemp('upd');
      expect(
        () => svc.downloadApk(
          url: 'https://example.com/cofiz.apk',
          destPath: '${dir.path}/a.apk',
          isCancelled: () async => false,
        ),
        throwsStateError,
      );
    });
  });

  group('ReleaseInfo json round-trip', () {
    test('survives cache encode/decode, rejects junk', () {
      const r = ReleaseInfo(
        version: 'v1.2.0',
        tag: 'v1.2.0',
        notes: 'n',
        apkUrl: 'https://example.com/a.apk',
        htmlUrl: 'https://example.com/r',
      );
      final back =
          ReleaseInfo.fromJson(jsonDecode(jsonEncode(r.toJson())));
      expect(back!.apkUrl, r.apkUrl);
      expect(ReleaseInfo.fromJson({'version': '', 'apkUrl': ''}), isNull);
    });
  });

  group('parseMinVersion', () {
    test('parses marker', () {
      expect(parseMinVersion('Fixes\n<!-- min-version: 1.2.0 -->'), '1.2.0');
    });
    test('absent marker yields empty', () {
      expect(parseMinVersion('Just notes'), '');
    });
    test('malformed marker yields empty', () {
      expect(parseMinVersion('<!-- min-version: soon -->'), '');
    });
    test('surfaces on parsed releases', () async {
      final http = FakeUpdateHttp()
        ..releaseJson = releaseJson(tag: 'v1.3.0');
      http.releaseJson!['body'] = 'Big change\n<!-- min-version: 1.2.0 -->';
      final svc = await makeService(http);
      final r = await svc.checkForUpdates(currentVersion: '1.1.0');
      expect(r!.minVersion, '1.2.0');
    });
  });
}
