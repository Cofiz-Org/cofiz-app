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
