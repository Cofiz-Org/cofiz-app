import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:cofiz/core/providers/phone_otp_auth_provider.dart';
import 'package:cofiz/core/services/auth_backend.dart';
import 'package:cofiz/l10n/app_localizations.dart';
import 'package:cofiz/presentation/screens/auth/phone_login_screen.dart';
import '../../../_support/mock_http_client.dart';

void main() {
  testWidgets('PhoneLoginScreen shows two buttons, reveals phone field after WhatsApp tap', (tester) async {
    final mock = MockHttpClient();
    mock.onPost('/auth/whatsapp/start', (_) => {'challengeId': 'v1', 'expiresIn': 300});
    final provider = PhoneOtpAuthProvider(
      backend: AuthBackend(baseUrl: 'https://x', client: mock),
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ChangeNotifierProvider.value(
          value: provider,
          child: const PhoneLoginScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('continueWithTelegramButton')), findsOneWidget);
    expect(find.byKey(const Key('continueWithWhatsappButton')), findsOneWidget);
    expect(find.byKey(const Key('sendCodeButton')), findsNothing);
    await tester.tap(find.byKey(const Key('continueWithWhatsappButton')));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const Key('sendCodeButton')), findsOneWidget);
    expect(find.byKey(const Key('whatsappPhoneField')), findsOneWidget);
    await tester.pumpAndSettle();
  });
}
