# Daily Coffee Price Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Admin sets a daily per-type coffee price from the dashboard; all roles see it; above-price purchases warn and flag.

**Architecture:** New `DailyPriceProvider` owns the `settings/daily_prices/{YYYY-MM-DD}` doc (Addis date, per-type merge writes). Dashboard chip + modal for set/edit. `NotificationTriggerService.notifyDailyPriceSet` reuses the bell+email+relay fan-out. Purchase dialog compares and stores snapshot + flag.

**Tech Stack:** Flutter, cloud_firestore, FakeFirebaseFirestore + flutter_test, flutter_gen-l10n.

## Global Constraints

- Addis Ababa wall date (`Africa/Addis_Ababa`, UTC+3, no DST) for the daily doc id.
- A price is valid only when the doc date equals today; no cron, no worker changes.
- `companyId` defaults to `"cofiz"`; missing field reads as default.
- Above-price never blocks save.
- Existing test style: `FakeFirebaseFirestore`, `MockClient` for relay HTTP, `SharedPreferences.setMockInitialValues({})`.

---

### Task 1: Rename yetatebe to wet, Wet default

**Files:**
- Modify: `lib/core/constants/coffee_types.dart`
- Modify: `lib/l10n/app_en.arb` (line ~89 `"yetatebe": "Washed"` → `"wet": "Wet"`)
- Modify: `lib/l10n/app_am.arb` (line ~89 `"yetatebe": "የታጠበ"` → `"wet": "እርጥብ"`)
- Modify: `lib/presentation/screens/transaction/transaction_dialog.dart:73-76` (default selection), `:529-534` (dropdown labels)
- Modify: `lib/presentation/screens/worker/widgets/worker_transaction_tile.dart:225-233` (`_coffeeTypeLabel`)
- Modify: `lib/presentation/screens/reports/reports_screen.dart:1380-1400` (`_coffeeTypeLabel`)
- Test: `test/core/constants/coffee_types_test.dart` (create)

**Interfaces:**
- Consumes: nothing.
- Produces: `CoffeeType.wet` (enum value), historical `'yetatebe'` strings map to Wet in display helpers.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/constants/coffee_types.dart';

void main() {
  test('wet exists with Wet display name', () {
    expect(CoffeeType.values.map((t) => t.name), contains('wet'));
    expect(CoffeeType.wet.displayName, 'Wet');
  });

  test('no yetatebe value remains', () {
    expect(CoffeeType.values.map((t) => t.name), isNot(contains('yetatebe')));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/constants/coffee_types_test.dart`
Expected: FAIL (no `wet` value yet)

- [ ] **Step 3: Rename the enum and display**

```dart
enum CoffeeType {
  jenfel,
  wet,
  special;

  String get displayName {
    switch (this) {
      case CoffeeType.jenfel:
        return 'Dried';
      case CoffeeType.wet:
        return 'Wet';
      case CoffeeType.special:
        return 'Special';
    }
  }

  String get id {
    return name;
  }
}
```

- [ ] **Step 4: Update arb keys, dialog default + labels, historical display fallbacks**

arb en: replace `"yetatebe": "Washed",` with `"wet": "Wet",`.
arb am: replace `"yetatebe": "የታጠበ",` with `"wet": "እርጥብ",`.
Run: `flutter gen-l10n` (regenerates `lib/l10n/app_localizations_*.dart`).

`transaction_dialog.dart` default (existing null → Wet):

```dart
_selectedCoffeeType = existing.coffeeType == null
    ? CoffeeType.wet
    : CoffeeType.values
        .where((t) => t.name == existing.coffeeType)
        .firstOrNull ?? CoffeeType.wet;
```

Dropdown labels: `case CoffeeType.yetatebe: return l?.yetatebe ?? 'Washed';` →
`case CoffeeType.wet: return l?.wet ?? 'Wet';`.

Historical fallback in `worker_transaction_tile.dart` and `reports_screen.dart`
`_coffeeTypeLabel` (stored docs still say `yetatebe`):

```dart
case 'yetatebe':
case 'wet':
  return l10n?.wet ?? 'Wet';
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/core/constants/coffee_types_test.dart`
Expected: PASS. Then: `flutter analyze lib/core/constants/coffee_types.dart lib/presentation/screens/transaction/transaction_dialog.dart`

- [ ] **Step 6: Commit**

```bash
git add lib/core/constants/coffee_types.dart lib/l10n/app_en.arb lib/l10n/app_am.arb lib/l10n/app_localizations*.dart lib/presentation/screens/transaction/transaction_dialog.dart lib/presentation/screens/worker/widgets/worker_transaction_tile.dart lib/presentation/screens/reports/reports_screen.dart test/core/constants/coffee_types_test.dart
git commit -m "feat: rename yetatebe to wet, default dropdowns to wet"
```

---

### Task 2: New l10n strings for daily price

**Files:**
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_am.arb`
- Test: none (covered by widget tests in Tasks 5–6; verify via gen-l10n output)

**Interfaces:**
- Consumes: nothing.
- Produces keys: `dailyPrice`, `setDailyPrice`, `priceNotSetYet`, `pricePerKgToday`, `aboveDailyPriceWarning`, `priceUpdate`, `dailyPriceSetBody`.

- [ ] **Step 1: Append arb entries**

en (`app_en.arb`):

```json
"dailyPrice": "Daily price",
"setDailyPrice": "Set daily price",
"priceNotSetYet": "Today's price not set yet",
"aboveDailyPriceWarning": "Above today's {type} price of {price}/kg",
"dailyPriceSetTitle": "Today's coffee prices are set",
```

am (`app_am.arb`):

```json
"dailyPrice": "ዕለታዊ ዋጋ",
"setDailyPrice": "ዕለታዊ ዋጋ አቆም",
"priceNotSetYet": "የዛሬ ዋጋ እስካሁን አልተቆጠረም",
"aboveDailyPriceWarning": "ከዛሬ {type} ዋጋ {price}/ኪግ በላይ",
"dailyPriceSetTitle": "የዛሬ የቡና ዋጋዎች ተቀምጠዋል",
```

- [ ] **Step 2: Regenerate and verify**

Run: `flutter gen-l10n`
Expected: no errors; `grep -n "priceNotSetYet" lib/l10n/app_localizations.dart` shows the getter.

- [ ] **Step 3: Commit**

```bash
git add lib/l10n/app_en.arb lib/l10n/app_am.arb lib/l10n/app_localizations*.dart
git commit -m "feat: l10n strings for daily coffee price"
```

---

### Task 3: companyId + canManagePrices + transaction price fields

**Files:**
- Modify: `lib/core/models/user_model.dart` (`AppUser`: field, fromFirestore, toFirestore, fromJson, copyWith)
- Modify: `lib/core/models/transaction_model.dart` (`MoneyTransaction`: `dailyPriceAtSale`, `aboveDailyPrice` in constructor, fromFirestore, toFirestore, fromJson, copyWith)
- Test: extend `test/core/models/transaction_model_test.dart` (check it exists; if not, create `test/core/models/daily_price_fields_test.dart`)

**Interfaces:**
- Consumes: nothing.
- Produces: `UserRole.canManagePrices` (bool, admin-only), `AppUser.companyId` (default `"cofiz"`), transaction `dailyPriceAtSale`/`aboveDailyPrice` round-trip.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/models/user_model.dart';
import 'package:cofiz/core/models/transaction_model.dart';

void main() {
  test('admin manages prices, others do not', () {
    expect(UserRole.admin.canManagePrices, isTrue);
    expect(UserRole.worker.canManagePrices, isFalse);
    expect(UserRole.viewer.canManagePrices, isFalse);
  });

  test('companyId defaults to cofiz when absent', () {
    final u = AppUser.fromFirestore({'role': 'worker'}, 'uid1');
    expect(u.companyId, 'cofiz');
  });

  test('transaction price snapshot round-trips', () {
    final t = MoneyTransaction(
      id: 't1', workerId: 'w', workerName: 'W', type: 'purchase',
      amount: 100, createdAt: DateTime(2026, 9, 11), createdBy: 'a',
      pricePerKg: 400, dailyPriceAtSale: 380, aboveDailyPrice: true,
    );
    final back = MoneyTransaction.fromFirestore(t.toFirestore(), 't1');
    expect(back.dailyPriceAtSale, 380);
    expect(back.aboveDailyPrice, isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/models/daily_price_fields_test.dart`
Expected: FAIL (members missing)

- [ ] **Step 3: Implement model changes**

`user_model.dart`: add `final String companyId;` (default `'cofiz'` in constructor),
`companyId: data['companyId'] as String? ?? 'cofiz'` in fromFirestore/fromJson,
`'companyId': companyId` in toFirestore/toJson, `String? companyId` in copyWith.

`user_model.dart` permissions block:

```dart
bool get canManagePrices => this == UserRole.admin;
```

`transaction_model.dart`: add `final double? dailyPriceAtSale;` and
`final bool aboveDailyPrice;` (default `false`); thread through constructor,
fromFirestore (`(data['dailyPriceAtSale'] as num?)?.toDouble()`,
`data['aboveDailyPrice'] == true`), toFirestore/fromJson/copyWith.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/models/daily_price_fields_test.dart test/core/models/transaction_model_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/models/user_model.dart lib/core/models/transaction_model.dart test/core/models/daily_price_fields_test.dart
git commit -m "feat: companyId, canManagePrices, transaction daily-price snapshot fields"
```

---

### Task 4: DailyPriceProvider

**Files:**
- Create: `lib/core/providers/daily_price_provider.dart`
- Modify: `lib/main.dart:185` (register `ChangeNotifierProvider(create: (_) => DailyPriceProvider())` after SettingsProvider)
- Test: `test/core/providers/daily_price_provider_test.dart` (create)

**Interfaces:**
- Consumes: `cloud_firestore` (injected, faked in tests), Addis date helper (inline, UTC+3).
- Produces: `DailyPriceProvider.todayKey` (e.g. `"2026-09-11"`), `priceFor(CoffeeType) → double?`, `selectedType` (default `CoffeeType.wet`), `setSelectedType`, `savePrice({required CoffeeType type, required double price, String? setBy})`, `isSetFor(CoffeeType)`, `yesterdayPriceFor(CoffeeType)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cofiz/core/constants/coffee_types.dart';
import 'package:cofiz/core/providers/daily_price_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saves one type without wiping others', () async {
    SharedPreferences.setMockInitialValues({});
    final fake = FakeFirebaseFirestore();
    final p = DailyPriceProvider(firestore: fake, companyId: 'cofiz');
    await p.savePrice(type: CoffeeType.wet, price: 380, setBy: 'admin1');
    await p.savePrice(type: CoffeeType.jenfel, price: 420, setBy: 'admin1');
    expect(p.priceFor(CoffeeType.wet), 380);
    expect(p.priceFor(CoffeeType.jenfel), 420);
    expect(p.isSetFor(CoffeeType.special), isFalse);
  });

  test('defaults selected type to wet', () async {
    SharedPreferences.setMockInitialValues({});
    final p = DailyPriceProvider(
        firestore: FakeFirebaseFirestore(), companyId: 'cofiz');
    expect(p.selectedType, CoffeeType.wet);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/providers/daily_price_provider_test.dart`
Expected: FAIL (class missing)

- [ ] **Step 3: Implement provider**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/coffee_types.dart';

class DailyPriceProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final String companyId;

  DailyPriceProvider({FirebaseFirestore? firestore, this.companyId = 'cofiz'})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _loadToday();
  }

  Map<String, double> _prices = {};
  Map<String, double> _yesterday = {};
  CoffeeType _selectedType = CoffeeType.wet;

  Map<String, double> get prices => Map.unmodifiable(_prices);
  CoffeeType get selectedType => _selectedType;

  static String addisDateKey([DateTime? now]) {
    final addis = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
    final m = addis.month.toString().padLeft(2, '0');
    final d = addis.day.toString().padLeft(2, '0');
    return '${addis.year}-$m-$d';
  }

  String get todayKey => addisDateKey();

  double? priceFor(CoffeeType type) => _prices[type.name];
  bool isSetFor(CoffeeType type) => _prices.containsKey(type.name);
  double? yesterdayPriceFor(CoffeeType type) => _yesterday[type.name];

  void setSelectedType(CoffeeType type) {
    if (_selectedType == type) return;
    _selectedType = type;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> _doc(String dateKey) => _firestore
      .collection('settings')
      .doc('daily_prices')
      .collection(dateKey)
      .doc(companyId);

  static Map<String, double> _readPrices(Map<String, dynamic>? data) {
    final out = <String, double>{};
    final raw = data?['prices'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = (v as num?)?.toDouble();
        if (n != null && n > 0) out[k.toString()] = n;
      });
    }
    return out;
  }

  Future<void> _loadToday() async {
    try {
      final today = await _doc(todayKey).get().timeout(const Duration(seconds: 5));
      _prices = _readPrices(today.data());
      final yKey = addisDateKey(DateTime.now().subtract(const Duration(days: 1)));
      final y = await _doc(yKey).get().timeout(const Duration(seconds: 5));
      _yesterday = _readPrices(y.data());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> savePrice(
      {required CoffeeType type, required double price, String? setBy}) async {
    if (price <= 0) throw ArgumentError('price must be positive');
    _prices[type.name] = price;
    notifyListeners();
    try {
      await _doc(todayKey).set({
        'companyId': companyId,
        'prices': {type.name: price},
        if (setBy != null) 'setBy': setBy,
        'setAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
```

NOTE: doc path is `settings/daily_prices/{dateKey}/{companyId}` (subcollection
under a container doc — avoids the 1MB `settings/app` growth and keeps per-day
history queryable). Adjust spec doc accordingly when implementing.

- [ ] **Step 4: Register in main.dart and run tests**

Add after the SettingsProvider line:

```dart
ChangeNotifierProvider(create: (_) => DailyPriceProvider()),
```

Run: `flutter test test/core/providers/daily_price_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/providers/daily_price_provider.dart lib/main.dart test/core/providers/daily_price_provider_test.dart
git commit -m "feat: DailyPriceProvider with per-type merge saves"
```

---

### Task 5: Dashboard price chip + type switcher

**Files:**
- Create: `lib/presentation/widgets/daily_price_chip.dart`
- Modify: `lib/presentation/screens/dashboard/dashboard_screen.dart:98-133` (insert chip row: admin `+` right of bell OR price chip; type label cycles on tap)
- Test: `test/presentation/widgets/daily_price_chip_test.dart` (create)

**Interfaces:**
- Consumes: `DailyPriceProvider` (watch), `AuthProvider`/role (`canManagePrices`), l10n keys from Task 2.
- Produces: chip states — admin-unset shows `+`, admin-set shows price (tap → Task 6 modal), non-admin shows price or `priceNotSetYet`.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cofiz/core/constants/coffee_types.dart';
import 'package:cofiz/core/providers/daily_price_provider.dart';
import 'package:cofiz/l10n/app_localizations.dart';
import 'package:cofiz/presentation/widgets/daily_price_chip.dart';

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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/daily_price_chip_test.dart`
Expected: FAIL (widget missing)

- [ ] **Step 3: Implement the chip**

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/coffee_types.dart';
import '../../core/providers/daily_price_provider.dart';
import '../../l10n/app_localizations.dart';

class DailyPriceChip extends StatelessWidget {
  const DailyPriceChip(
      {super.key, required this.isAdmin, this.onEditRequested});

  final bool isAdmin;
  final VoidCallback? onEditRequested;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final prices = context.watch<DailyPriceProvider>();
    final type = prices.selectedType;
    final price = prices.priceFor(type);
    final typeLabel = _typeLabel(l10n, type);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: () => prices.setSelectedType(_next(type)),
          child: Text(typeLabel,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ),
        const SizedBox(width: 6),
        if (price != null)
          GestureDetector(
            onTap: isAdmin ? onEditRequested : null,
            child: Text('${price.toStringAsFixed(0)}/kg',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
          )
        else if (isAdmin)
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white, size: 28),
            tooltip: l10n?.setDailyPrice ?? 'Set daily price',
            onPressed: onEditRequested,
          )
        else
          Text(l10n?.priceNotSetYet ?? "Today's price not set yet",
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }

  CoffeeType _next(CoffeeType t) => CoffeeType
      .values[(CoffeeType.values.indexOf(t) + 1) % CoffeeType.values.length];

  String _typeLabel(AppLocalizations? l10n, CoffeeType t) {
    switch (t) {
      case CoffeeType.jenfel:
        return l10n?.jenfel ?? 'Dried';
      case CoffeeType.wet:
        return l10n?.wet ?? 'Wet';
      case CoffeeType.special:
        return l10n?.special ?? 'Special';
    }
  }
}
```

Wire into `dashboard_screen.dart` header Row (after the bell `NotificationBadge`):
pass `isAdmin: authProvider.appUser?.role.canManagePrices ?? false` — add
`canManagePrices` getter in Task 3; if the role object available is `UserRole`,
use `authProvider.isAdmin` for now and switch when Task 3 lands. `onEditRequested`
opens the Task 6 modal.

- [ ] **Step 4: Run tests**

Run: `flutter test test/presentation/widgets/daily_price_chip_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/daily_price_chip.dart lib/presentation/screens/dashboard/dashboard_screen.dart test/presentation/widgets/daily_price_chip_test.dart
git commit -m "feat: dashboard daily-price chip with type switcher"
```

---

### Task 6: Price set/edit modal

**Files:**
- Create: `lib/presentation/widgets/daily_price_modal.dart`
- Test: extend `test/presentation/widgets/daily_price_chip_test.dart` (modal prefill + save flow)

**Interfaces:**
- Consumes: `DailyPriceProvider.savePrice`, `yesterdayPriceFor`, `AuthProvider.appUser.uid` (setBy).
- Produces: today's per-type price persisted; caller triggers Task 7 fan-out after save.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('modal prefills yesterday price and saves', (tester) async {
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
```

(Adjust button finder to the modal's actual Save label from Task 2 keys.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/presentation/widgets/daily_price_chip_test.dart`
Expected: FAIL (`showDailyPriceModal` missing)

- [ ] **Step 3: Implement the modal**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/coffee_types.dart';
import '../../core/providers/daily_price_provider.dart';
import '../../l10n/app_localizations.dart';

Future<double?> showDailyPriceModal(BuildContext context) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _DailyPriceSheet(),
  );
}

class _DailyPriceSheet extends StatefulWidget {
  const _DailyPriceSheet();

  @override
  State<_DailyPriceSheet> createState() => _DailyPriceSheetState();
}

class _DailyPriceSheetState extends State<_DailyPriceSheet> {
  late CoffeeType _type;
  final _ctl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final p = context.read<DailyPriceProvider>();
    _type = p.selectedType;
    final existing = p.priceFor(_type) ?? p.yesterdayPriceFor(_type);
    if (existing != null) _ctl.text = existing.toStringAsFixed(0);
  }

  void _pick(CoffeeType t) {
    final p = context.read<DailyPriceProvider>();
    setState(() {
      _type = t;
      final existing = p.priceFor(t) ?? p.yesterdayPriceFor(t);
      _ctl.text = existing != null ? existing.toStringAsFixed(0) : '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentedButton<CoffeeType>(
            segments: CoffeeType.values
                .map((t) => ButtonSegment(
                    value: t, label: Text(_label(l10n, t))))
                .toList(),
            selected: {_type},
            onSelectionChanged: (s) => _pick(s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
            ],
            decoration: InputDecoration(
              labelText: 'ETB / kg',
              suffixText: 'ETB/kg',
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final v = double.tryParse(_ctl.text.trim());
              if (v == null || v <= 0) return;
              await context
                  .read<DailyPriceProvider>()
                  .savePrice(type: _type, price: v);
              if (context.mounted) Navigator.pop(context, v);
            },
            child: const Text('Save'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _label(AppLocalizations l10n, CoffeeType t) {
    switch (t) {
      case CoffeeType.jenfel:
        return l10n.jenfel;
      case CoffeeType.wet:
        return l10n.wet;
      case CoffeeType.special:
        return l10n.special;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }
}
```

Use Task 2 l10n keys for the Save label/title where they fit.

- [ ] **Step 4: Run tests**

Run: `flutter test test/presentation/widgets/daily_price_chip_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/widgets/daily_price_modal.dart test/presentation/widgets/daily_price_chip_test.dart
git commit -m "feat: daily price set/edit modal with yesterday prefill"
```

---

### Task 7: Price-set fan-out to all users

**Files:**
- Modify: `lib/core/services/notification_trigger_service.dart` (add `notifyDailyPriceSet`)
- Modify: `lib/core/utils/app_navigator.dart` (add `dailyPriceSet` case → `NotificationsScreen`)
- Test: `test/core/services/daily_price_fanout_test.dart` (create, mirrors `notification_trigger_service_test.dart` relay stubbing)

**Interfaces:**
- Consumes: `PushRelayService` (injected), Firestore `users` by role.
- Produces: `notifyDailyPriceSet({required String setByName, required Map<String, double> prices})` — bell doc + email + relay push per admin, worker, and viewer.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:cofiz/core/services/notification_trigger_service.dart';
import 'package:cofiz/core/services/push_relay_service.dart';

void main() {
  test('price set notifies all roles', () async {
    final firestore = FakeFirebaseFirestore();
    final requests = <http.Request>[];
    final relay = PushRelayService(
      firestore: firestore,
      httpClient: MockClient(
          (request) async => http.Response('{"sent":true}', 200)),
      relayUrl: 'https://relay.example.com/push',
      relaySecret: 'secret123',
    );
    for (final entry in {'a1': 'admin', 'w1': 'worker', 'v1': 'viewer'}.entries) {
      await firestore.collection('users').doc(entry.key).set({
        'role': entry.value,
        'email': '${entry.key}@example.com',
      });
    }
    final svc =
        NotificationTriggerService(firestore: firestore, pushRelay: relay);
    await svc.notifyDailyPriceSet(
        setByName: 'Admin', prices: {'wet': 380, 'jenfel': 420});
    final docs = await firestore.collection('notifications').get();
    expect(docs.docs.length, 3);
    expect(requests.length, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/daily_price_fanout_test.dart`
Expected: FAIL (method missing)

- [ ] **Step 3: Implement fan-out**

```dart
Future<void> notifyDailyPriceSet({
  required String setByName,
  required Map<String, double> prices,
  String? senderId,
}) async {
  final parts = prices.entries
      .map((e) => '${e.key}: ETB ${e.value.toStringAsFixed(0)}/kg')
      .join(', ');
  final body = 'Today\'s prices — $parts (set by $setByName)';
  for (final role in ['admin', 'worker', 'viewer']) {
    try {
      final snap = await _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .get();
      for (final doc in snap.docs) {
        await _sendNotification(
          targetUserId: doc.id,
          title: 'Daily coffee prices',
          body: body,
          type: NotificationType.info,
          senderName: setByName,
          senderId: senderId,
          metadata: {
            for (final e in prices.entries) e.key: e.value,
          },
        );
      }
    } catch (e) {
      debugPrint('Error notifying $role of daily price: $e');
    }
  }
}
```

Check `NotificationType` enum for the right variant name (`info` assumed —
verify against `lib/core/models/notification_model.dart`; use whichever
generic variant exists, e.g. `info` or `general`).

`app_navigator.dart`: add explicit case (falls through to the list today,
but explicit is better):

```dart
case 'dailyPriceSet':
  return const NotificationsScreen();
```

Caller: dashboard/modal save handler invokes `notifyDailyPriceSet` after
`savePrice` succeeds (best-effort, unawaited with error swallow like the
ping flows).

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/services/daily_price_fanout_test.dart test/core/services/notification_trigger_service_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/notification_trigger_service.dart lib/core/utils/app_navigator.dart test/core/services/daily_price_fanout_test.dart
git commit -m "feat: daily price set fan-out to all roles"
```

---

### Task 8: Purchase dialog warning + snapshot threading

**Files:**
- Modify: `lib/presentation/screens/transaction/transaction_dialog.dart` (price hint + amber warning)
- Modify: `lib/core/providers/transaction_provider.dart:recordPurchase` (accept `dailyPriceAtSale`, `aboveDailyPrice`; set on both Firestore and optimistic models)
- Test: extend `test/core/providers/transaction_provider_test.dart` (above-price flags stored)

**Interfaces:**
- Consumes: `DailyPriceProvider.priceFor`, Task 2 `aboveDailyPriceWarning` key.
- Produces: purchases carry snapshot + flag; dialog warns without blocking.

- [ ] **Step 1: Write the failing test**

```dart
test('purchase above daily price stores snapshot and flag', () async {
  // ... existing provider setup with FakeFirebaseFirestore ...
  final id = await provider.recordCoffeePurchase(
    workerId: 'w1',
    workerName: 'W',
    amount: 4000,
    createdBy: 'admin1',
    coffeeType: 'wet',
    weight: 10,
    pricePerKg: 400,
    dailyPriceAtSale: 380,
    aboveDailyPrice: true,
  );
  expect(id, isNotNull);
  final doc =
      await fake.collection('transactions').doc(id!).get();
  expect(doc.data()?['dailyPriceAtSale'], 380);
  expect(doc.data()?['aboveDailyPrice'], isTrue);
});
```

(Match the existing `recordCoffeePurchase` call shape in
`test/core/providers/transaction_provider_test.dart`; only the two new
named params are added.)

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/providers/transaction_provider_test.dart`
Expected: FAIL (unknown named params)

- [ ] **Step 3: Thread params through provider**

Add to `recordCoffeePurchase` signature:

```dart
double? dailyPriceAtSale,
bool aboveDailyPrice = false,
```

Set on the `MoneyTransaction` constructor call and on the `_optimisticInsert`
copy. Dialog computes before calling:

```dart
final dayPrice =
    context.read<DailyPriceProvider>().priceFor(_selectedCoffeeType ?? CoffeeType.wet);
final above = dayPrice != null && price != null && price > dayPrice;
```

Dialog UI under the price field (only when `dayPrice != null`):

```dart
if (dayPrice != null)
  Text('Today: ${dayPrice.toStringAsFixed(0)}/kg',
      style: const TextStyle(fontSize: 12, color: Colors.grey)),
if (above)
  Text(
    AppLocalizations.of(context)!.aboveDailyPriceWarning
        .replaceFirst('{type}', label)
        .replaceFirst('{price}', dayPrice.toStringAsFixed(0)),
    style: const TextStyle(fontSize: 12, color: Colors.amber),
  ),
```

Save proceeds regardless.

- [ ] **Step 4: Run tests**

Run: `flutter test test/core/providers/transaction_provider_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/presentation/screens/transaction/transaction_dialog.dart lib/core/providers/transaction_provider.dart test/core/providers/transaction_provider_test.dart
git commit -m "feat: above-daily-price warning and snapshot on purchases"
```

---

### Task 9: Full suite, analyze, final commit check

- [ ] **Step 1: Run full suite**

Run: `flutter test`
Expected: all PASS (a `.env` stub from `.env.example` is needed locally;
CI materializes the real one — same as current workflow)

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 3: Verify spec coverage**

Every spec line maps: model (§1→Tasks 1,3), chip/modal (§2→Tasks 5,6,7,8),
edge cases (§3→Tasks 4,5). Rename + default + fan-out + warning all have tasks.

- [ ] **Step 4: Ship**

Bump `pubspec.yaml` patch version, extend `CHANGELOG_NOTES.md`, tag and
release through the existing pipeline (guard checks tag == pubspec version).
