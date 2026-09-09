import 'dart:convert';

import 'package:cofiz/core/providers/update_provider.dart';
import 'package:cofiz/core/providers/auth_provider.dart';
import 'package:cofiz/core/providers/density_provider.dart';
import 'package:cofiz/core/providers/settings_provider.dart';
import 'package:cofiz/core/providers/theme_provider.dart';
import 'package:cofiz/core/services/update_service.dart';
import 'package:cofiz/l10n/app_localizations.dart';
import 'package:cofiz/presentation/screens/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> releaseJson(String tag, String body) => {
      'tag_name': tag,
      'prerelease': false,
      'draft': false,
      'body': body,
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
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(releaseJson ?? {}))), 200);
  }
}

Future<UpdateProvider> providerFor(String current, String tag, String body) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final http = FakeUpdateHttp()..releaseJson = releaseJson(tag, body);
  final p = UpdateProvider(
    service: UpdateService(prefs: prefs, client: http, repo: 'o/r'),
    versionLoader: () async => current,
  );
  await p.initialize();
  return p;
}

Widget wrap(UpdateProvider p) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ChangeNotifierProvider<UpdateProvider>.value(
        value: p,
        child: Builder(
          builder: (context) => Provider.of<UpdateProvider>(context).isForceBlocked
              ? const _GateProbe()
              : const Text('settings-list'),
        ),
      ),
    ),
  );
}

class _GateProbe extends StatelessWidget {
  const _GateProbe();
  @override
  Widget build(BuildContext context) {
    return const Text('force-gate');
  }
}

void main() {
  test('provider blocks below floor and dismiss is a no-op', () async {
    final p = await providerFor('1.1.0', 'v1.3.0', 'Big\n<!-- min-version: 1.2.0 -->');
    expect(p.isForceBlocked, isTrue);
    await p.dismiss();
    expect(p.isForceBlocked, isTrue);
    expect(p.status, UpdateStatus.available);
  });

  test('provider allows at or above floor', () async {
    final p = await providerFor('1.2.0', 'v1.3.0', 'Big\n<!-- min-version: 1.2.0 -->');
    expect(p.isForceBlocked, isFalse);
    final q = await providerFor('1.3.0', 'v1.3.0', 'Big\n<!-- min-version: 1.2.0 -->');
    expect(q.isForceBlocked, isFalse);
  });

  testWidgets('blocked shows gate, allowed shows list', (tester) async {
    final blocked = await providerFor('1.1.0', 'v1.3.0', 'Big\n<!-- min-version: 1.2.0 -->');
    await tester.pumpWidget(wrap(blocked));
    await tester.pumpAndSettle();
    expect(find.text('force-gate'), findsOneWidget);

    final allowed = await providerFor('1.2.5', 'v1.3.0', 'Small fix');
    await tester.pumpWidget(wrap(allowed));
    await tester.pumpAndSettle();
    expect(find.text('settings-list'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders gate when blocked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = await providerFor('1.1.0', 'v1.3.0', 'Big\n<!-- min-version: 1.2.0 -->');
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<UpdateProvider>.value(value: p),
          ChangeNotifierProvider(create: (_) => ThemeProvider()),
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => DensityProvider()),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const SettingsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Update required'), findsOneWidget);
    expect(find.byKey(const Key('forceStart')), findsOneWidget);
  });
}
