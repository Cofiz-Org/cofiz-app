import 'package:flutter_test/flutter_test.dart';
import 'package:cofiz/core/models/debt_model.dart';

void main() {
  group('Debt round-trip', () {
    test('toFirestore/fromMap preserves fields', () {
      final d = Debt(
        id: 'd1',
        collectorId: 'c1',
        collectorName: 'Alice',
        purchaseId: 'p1',
        totalAmount: 1000,
        coveredAmount: 400,
        forgivenAmount: 600,
        status: DebtStatus.open,
        createdAt: DateTime(2026, 8, 29),
        createdBy: 'u1',
      );
      final m = d.toFirestore();
      expect(m['collectorId'], 'c1');
      expect(m['forgivenAmount'], 600.0);
      expect(m['status'], 'open');
      final back = Debt.fromMap({...m, 'id': 'd1'}, id: 'd1');
      expect(back.coveredAmount, 400);
      expect(back.status, DebtStatus.open);
      expect(back.id, 'd1');
    });

    test('source defaults to purchase and round-trips', () {
      final d = Debt(
        id: 'd3',
        collectorId: Debt.companyCollectorId,
        collectorName: Debt.companyCollectorName,
        source: 'expense',
        purchaseId: 'exp-1',
        totalAmount: 800,
        coveredAmount: 300,
        forgivenAmount: 500,
        status: DebtStatus.open,
        createdAt: DateTime(2026, 8, 29),
        createdBy: 'u1',
      );
      final back = Debt.fromMap(d.toFirestore(), id: 'd3');
      expect(back.source, 'expense');
      expect(back.collectorId, Debt.companyCollectorId);
      expect(back.purchaseId, 'exp-1');
      final legacy = Debt.fromMap({
        'collectorId': 'c9',
        'forgivenAmount': 10,
      });
      expect(legacy.source, 'purchase');
    });

    test('paidAt survives round-trip', () {
      final now = DateTime(2026, 8, 30);
      final d = Debt(
        id: 'd2',
        collectorId: 'c2',
        collectorName: 'Bob',
        purchaseId: 'p2',
        totalAmount: 500,
        coveredAmount: 300,
        forgivenAmount: 200,
        status: DebtStatus.paid,
        createdAt: DateTime(2026, 8, 29),
        paidAt: now,
        createdBy: 'u1',
      );
      final back = Debt.fromMap(d.toFirestore(), id: 'd2');
      expect(back.paidAt?.millisecondsSinceEpoch, now.millisecondsSinceEpoch);
      expect(back.status, DebtStatus.paid);
    });
  });
}
