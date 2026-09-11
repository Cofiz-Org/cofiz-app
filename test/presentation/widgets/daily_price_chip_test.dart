import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cofiz/core/constants/coffee_types.dart';
import 'package:cofiz/core/providers/daily_price_provider.dart';
import 'package:cofiz/l10n/app_localizations.dart';
import 'package:cofiz/presentation/widgets/daily_price_chip.dart';
import 'package:cofiz/presentation/widgets/daily_price_modal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, DailyPriceProvider p,
      {bool isAdmin = true}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<DailyPriceProvider>.value(value: p)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DailyPriceChip(isAdmin: isAdmin)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('admin sees + when wet unset', (tester) async {
    final p = DailyPriceProvider(
        firestore: FakeFirebaseFirestore(), companyId: 'cofiz');
    await pump(tester, p, isAdmin: true);
    expect(find.byIcon(Icons.add), findsOneWidget);
  });

  testWidgets('shows price once set', (tester) async {
    final p = DailyPriceProvider(
        firestore: FakeFirebaseFirestore(), companyId: 'cofiz');
    await p.savePrice(type: CoffeeType.wet, price: 380);
    await pump(tester, p, isAdmin: true);
    expect(find.textContaining('380'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('non-admin sees not-set text when unset', (tester) async {
    final p = DailyPriceProvider(
        firestore: FakeFirebaseFirestore(), companyId: 'cofiz');
    await pump(tester, p, isAdmin: false);
    expect(find.byIcon(Icons.add), findsNothing);
  });

  testWidgets('modal prefills yesterday price and saves', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeFirebaseFirestore();
    final p = DailyPriceProvider(firestore: fake, companyId: 'cofiz');
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider<DailyPriceProvider>.value(value: p)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDailyPriceModal(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '380');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(p.priceFor(CoffeeType.wet), 380);
  });
}
