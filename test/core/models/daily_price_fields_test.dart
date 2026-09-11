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
      id: 't1',
      workerId: 'w',
      workerName: 'W',
      type: 'purchase',
      amount: 100,
      createdAt: DateTime(2026, 9, 11),
      createdBy: 'a',
      pricePerKg: 400,
      dailyPriceAtSale: 380,
      aboveDailyPrice: true,
    );
    final back = MoneyTransaction.fromFirestore(t.toFirestore(), 't1');
    expect(back.dailyPriceAtSale, 380);
    expect(back.aboveDailyPrice, isTrue);
  });
}
