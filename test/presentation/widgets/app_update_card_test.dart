import 'dart:convert';

import 'package:cofiz/core/providers/update_provider.dart';
import 'package:cofiz/core/services/update_service.dart';
import 'package:cofiz/l10n/app_localizations.dart';
import 'package:cofiz/presentation/widgets/app_update_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> releaseJson(String tag) => {
      'tag_name': tag,
      'prerelease': false,
      'draft': false,
      'body': 'Fresh fixes and speedups',
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

Future<UpdateProvider> providerFor(String current, String latest) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final http = FakeUpdateHttp()..releaseJson = releaseJson(latest);
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
        child: const AppUpdateCard(),
      ),
    ),
  );
}

void main() {
  testWidgets('available update shows versions, notes and actions',
      (tester) async {
    final p = await providerFor('1.1.9', 'v1.2.0');
    await tester.pumpWidget(wrap(p));
    await tester.pumpAndSettle();

    expect(find.text('Update available'), findsOneWidget);
    expect(find.text('Update'), findsOneWidget);
    expect(find.text('Not now'), findsOneWidget);
    expect(find.textContaining('1.1.9'), findsOneWidget);
    expect(find.textContaining('v1.2.0'), findsOneWidget);
    expect(find.textContaining('Fresh fixes'), findsOneWidget);
  });

  testWidgets('dismiss returns card to up-to-date', (tester) async {
    final p = await providerFor('1.1.9', 'v1.2.0');
    await tester.pumpWidget(wrap(p));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    expect(find.textContaining("You're on the latest version"), findsOneWidget);
    expect(find.text('Check again'), findsOneWidget);
  });

  testWidgets('up-to-date shows version and check-again', (tester) async {
    final p = await providerFor('1.2.0', 'v1.2.0');
    await tester.pumpWidget(wrap(p));
    await tester.pumpAndSettle();

    expect(find.textContaining("You're on the latest version"), findsOneWidget);
    expect(find.byKey(const Key('updateCheckAgain')), findsOneWidget);
  });
}
