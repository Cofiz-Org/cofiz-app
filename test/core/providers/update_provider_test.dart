import 'dart:convert';
import 'dart:io';

import 'package:cofiz/core/providers/update_provider.dart';
import 'package:cofiz/core/services/update_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> releaseJson(String tag) => {
      'tag_name': tag,
      'prerelease': false,
      'draft': false,
      'body': 'Notes',
      'html_url': 'https://github.com/o/r/releases/tag/$tag',
      'published_at': '2026-09-01T00:00:00Z',
      'assets': [
        {
          'name': 'cofiz-$tag.apk',
          'browser_download_url': 'https://example.com/cofiz.apk',
        },
      ],
    };

class FakeUpdateHttp extends http.BaseClient {
  Map<String, dynamic>? releaseJson;
  bool throwOnLatest = false;
  List<int> apkBytes = utf8.encode('fake-apk');

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/releases/latest')) {
      if (throwOnLatest) throw const SocketException('offline');
      return http.StreamedResponse(
          Stream.value(utf8.encode(jsonEncode(releaseJson ?? {}))), 200);
    }
    return http.StreamedResponse(Stream.value(apkBytes), 200,
        contentLength: apkBytes.length);
  }
}

Future<UpdateService> serviceFor(FakeUpdateHttp http) async {
  SharedPreferences.setMockInitialValues({});
  return UpdateService(
      prefs: await SharedPreferences.getInstance(),
      client: http,
      repo: 'o/r');
}

void mockTempDir() {
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'getTemporaryDirectory') return Directory.systemTemp.path;
    return null;
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('initialize reports available when newer', () async {
    final http = FakeUpdateHttp()..releaseJson = releaseJson('v1.2.0');
    final p = UpdateProvider(
      service: await serviceFor(http),
      versionLoader: () async => '1.1.9',
    );
    await p.initialize();
    expect(p.status, UpdateStatus.available);
    expect(p.release!.version, 'v1.2.0');
    expect(p.currentVersion, '1.1.9');
  });

  test('initialize reports up-to-date when same', () async {
    final http = FakeUpdateHttp()..releaseJson = releaseJson('v1.2.0');
    final p = UpdateProvider(
      service: await serviceFor(http),
      versionLoader: () async => '1.2.0',
    );
    await p.initialize();
    expect(p.status, UpdateStatus.upToDate);
    expect(p.release, isNull);
  });

  test('user-initiated failure surfaces error, background stays silent',
      () async {
    final http = FakeUpdateHttp()
      ..releaseJson = releaseJson('v1.2.0')
      ..throwOnLatest = true;
    final bg = UpdateProvider(
      service: await serviceFor(http),
      versionLoader: () async => '1.1.9',
    );
    await bg.initialize();
    expect(bg.status, UpdateStatus.upToDate);
    expect(bg.errorMessage, isNull);

    final fg = UpdateProvider(
      service: await serviceFor(http),
      versionLoader: () async => '1.1.9',
    );
    await fg.initialize();
    await fg.checkForUpdates(force: true, userInitiated: true);
    expect(fg.status, UpdateStatus.error);
    expect(fg.errorMessage, isNotNull);
  });

  test('dismiss quiets the version', () async {
    final http = FakeUpdateHttp()..releaseJson = releaseJson('v1.2.0');
    final p = UpdateProvider(
      service: await serviceFor(http),
      versionLoader: () async => '1.1.9',
    );
    await p.initialize();
    expect(p.hasUpdate, isTrue);
    await p.dismiss();
    expect(p.hasUpdate, isFalse);
    expect(p.status, UpdateStatus.upToDate);
  });

  test('downloadAndInstall reaches ready and opens installer', () async {
    mockTempDir();
    final http = FakeUpdateHttp()..releaseJson = releaseJson('v1.2.0');
    String? opened;
    final p = UpdateProvider(
      service: await serviceFor(http),
      versionLoader: () async => '1.1.9',
      openInstaller: (path) async {
        opened = path;
        return OpenResult(type: ResultType.done);
      },
    );
    await p.initialize();
    await p.downloadAndInstall();
    expect(p.status, UpdateStatus.ready);
    expect(p.progress, 1.0);
    expect(opened, endsWith('.apk'));
    expect(await File(opened!).exists(), isTrue);
  });
}
