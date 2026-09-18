import 'package:cofiz/core/constants/coffee_types.dart';
import 'package:cofiz/core/models/user_model.dart';
import 'package:cofiz/core/providers/daily_price_provider.dart';
import 'package:cofiz/core/theme/app_theme.dart';
import 'package:cofiz/l10n/app_localizations.dart';
import 'package:cofiz/presentation/widgets/daily_price_modal.dart';
import 'package:cofiz/presentation/widgets/ping_admin_sheet.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('daily price picker selected segment uses primary',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final p = DailyPriceProvider(
        firestore: FakeFirebaseFirestore(), companyId: 'cofiz');
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
    final seg = tester.widget<SegmentedButton<CoffeeType>>(
        find.byType(SegmentedButton<CoffeeType>).first);
    expect(
        seg.style?.backgroundColor?.resolve({WidgetState.selected}),
        AppColors.primary);
  });

  testWidgets('ping preset ChoiceChip selected color is primary-tinted',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PingAdminSheet(
            role: UserRole.worker,
            isOnline: () => true,
            onSend: (_) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final chip =
        tester.widget<ChoiceChip>(find.byType(ChoiceChip).first);
    expect(chip.selectedColor,
        AppColors.primary.withValues(alpha: 0.2));
  });
}
