import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cofiz/core/models/expense_record_model.dart';
import 'package:cofiz/core/providers/expense_provider.dart';
import 'package:cofiz/core/services/expense_service.dart';
import 'package:cofiz/core/services/offline_cache_service.dart';

void main() {
  ExpenseRecord rec(double amount, DateTime createdAt) {
    return ExpenseRecord(
      id: '',
      amount: amount,
      expenseCategory: 'Rent',
      createdAt: createdAt,
      createdBy: 'u',
      createdByName: 'Admin',
    );
  }

  group('ExpenseProvider statics', () {
    test('sum totals amounts', () {
      final records = [
        rec(100, DateTime(2026, 8, 1)),
        rec(50, DateTime(2026, 8, 2)),
      ];
      expect(ExpenseProvider.sum(records), 150.0);
    });

    test('sumToday only counts today', () {
      final now = DateTime(2026, 8, 14, 12, 0);
      final records = [
        rec(100, DateTime(2026, 8, 14, 8, 0)),
        rec(40, DateTime(2026, 8, 13, 23, 0)),
      ];
      expect(ExpenseProvider.sumToday(records, now: now), 100.0);
    });
  });

  group('ExpenseProvider addExpense', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('expense_id_test');
      await OfflineCacheService().initialize(path: tempDir.path);
    });

    tearDownAll(() async {
      await OfflineCacheService().clearAllCache();
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    test('returns the new record id for debt linkage', () async {
      final p = ExpenseProvider(
          service: ExpenseService(firestore: FakeFirebaseFirestore()));
      final id = await p.addExpense(rec(250, DateTime.now()));
      expect(id, isNotNull);
      expect(p.records.any((r) => r.id == id), isTrue);
    });
  });
}
