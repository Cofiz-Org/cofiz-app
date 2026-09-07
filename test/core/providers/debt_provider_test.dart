import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cofiz/core/models/debt_model.dart';
import 'package:cofiz/core/providers/debt_provider.dart';
import 'package:cofiz/core/services/connectivity_service.dart';
import 'package:cofiz/core/services/debt_service.dart';
import 'package:cofiz/core/services/notification_trigger_service.dart';
import 'package:cofiz/core/services/offline_cache_service.dart';
import 'package:cofiz/core/services/offline_sync_service.dart';

void main() {
  late Directory tempDir;
  late FakeFirebaseFirestore fake;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('debt_provider_test');
    await OfflineCacheService().initialize(path: tempDir.path);
  });

  tearDownAll(() async {
    await OfflineCacheService().clearAllCache();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    fake = FakeFirebaseFirestore();
    OfflineSyncService().firestore = fake;
    await OfflineCacheService().clearAllCache();
  });

  DebtProvider provider() => DebtProvider(
        debtService: DebtService(firestore: fake),
        notificationService: NotificationTriggerService(firestore: fake),
      );

  Future<Debt> seedDebt(String collector, double forgiven) async {
    final d = await DebtService(firestore: fake).createDebtFromPurchase(
      collectorId: collector,
      collectorName: collector,
      purchaseId: 'p-$collector-$forgiven',
      totalAmount: forgiven + 100,
      coveredAmount: 100,
      forgivenAmount: forgiven,
      createdBy: 'u1',
    );
    final sync = OfflineSyncService();
    sync.firestore = fake;
    for (var i = 0; i < 40; i++) {
      await sync.syncPendingOperations();
      if (OfflineCacheService().getPendingOperations().isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    sync.dispose();
    return d;
  }

  test('initialize streams debts and derives open totals', () async {
    await seedDebt('c1', 600);
    await seedDebt('c2', 400);
    final p = provider();
    p.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(p.openDebts.length, 2);
    expect(p.openTotal, 1000);
    expect(p.openCountByCollector, {'c1': 1, 'c2': 1});
    expect(p.byCollector.keys.toSet(), {'c1', 'c2'});
    p.dispose();
  });

  test('markPaid flips status optimistically and keeps history', () async {
    final d = await seedDebt('c1', 600);
    final p = provider();
    p.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(p.openDebts.length, 1);
    await p.markPaid(d.id);
    expect(p.openDebts, isEmpty);
    expect(p.openTotal, 0);
    final mine = p.debtsForCollector('c1');
    expect(mine.length, 1);
    expect(mine.first.status, DebtStatus.paid);
    final snap = await fake.collection('debts').doc(d.id).get();
    expect(snap.data()!['status'], 'paid');
    p.dispose();
  });

  test('recordDebtFromPurchase links the real transaction id', () async {
    final p = provider();
    p.initialize();
    final debt = await p.recordDebtFromPurchase(
      collectorId: 'c9',
      collectorName: 'C9',
      purchaseId: 'tx-real-id-123',
      totalAmount: 1000,
      coveredAmount: 400,
      forgivenAmount: 600,
      createdBy: 'u1',
    );
    expect(debt.purchaseId, 'tx-real-id-123');
    expect(p.openDebts.any((d) => d.id == debt.id), isTrue);
    p.dispose();
  });

  test('recordDebtFromPurchase writes bell docs for admin and collector',
      () async {
    await fake.collection('users').doc('admin1').set({'role': 'admin'});
    await fake.collection('users').doc('user-c9').set({'role': 'worker'});
    await fake
        .collection('workers')
        .doc('c9')
        .set({'name': 'C9', 'userId': 'user-c9'});
    final p = provider();
    p.initialize();
    await p.recordDebtFromPurchase(
      collectorId: 'c9',
      collectorName: 'C9',
      purchaseId: 'tx-bell-1',
      totalAmount: 1000,
      coveredAmount: 400,
      forgivenAmount: 600,
      createdBy: 'u1',
    );
    final adminSnap = await fake
        .collection('notifications')
        .where('targetUserId', isEqualTo: 'admin1')
        .get();
    final collectorSnap = await fake
        .collection('notifications')
        .where('targetUserId', isEqualTo: 'user-c9')
        .get();
    expect(adminSnap.docs, hasLength(1));
    expect(collectorSnap.docs, hasLength(1));
    p.dispose();
  });

  test('company expense debt records with source and link', () async {
    final p = provider();
    p.initialize();
    final debt = await p.recordDebtFromPurchase(
      collectorId: Debt.companyCollectorId,
      collectorName: Debt.companyCollectorName,
      purchaseId: 'exp-99',
      totalAmount: 800,
      coveredAmount: 300,
      forgivenAmount: 500,
      createdBy: 'u1',
      source: 'expense',
      linkedName: 'Transport',
    );
    expect(debt.source, 'expense');
    expect(debt.purchaseId, 'exp-99');
    expect(p.openDebts.any((d) => d.id == debt.id), isTrue);
    expect(p.openTotal, 500);
    expect(p.debtsForCollector('c1'), isEmpty);
    p.dispose();
  });

  test('corrupt docs do not kill the list', () async {
    await seedDebt('c1', 600);
    await fake.collection('debts').add({'broken': true});
    final debts = await DebtService(firestore: fake).getAllDebts();
    expect(debts.length, 1);
    expect(debts.first.collectorId, 'c1');
  });

  test('tolerant parsing fills defaults but rejects identity-less docs', () {
    final d = Debt.fromMap({'collectorId': 'c1'});
    expect(d.forgivenAmount, 0.0);
    expect(d.status, DebtStatus.open);
    expect(d.collectorName, '');
    expect(() => Debt.fromMap({'broken': true}), throwsArgumentError);
  });

  test('records honors the day filter and clears', () async {
    await seedDebt('c1', 600);
    final p = provider();
    p.initialize();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(p.records.length, 1);
    p.loadDebtsForDay(DateTime.now());
    expect(p.records.length, 1);
    expect(p.activeDay, isNotNull);
    p.loadDebtsForDay(DateTime.now().subtract(const Duration(days: 2)));
    expect(p.records, isEmpty);
    p.clearDayFilter();
    expect(p.activeDay, isNull);
    expect(p.records.length, 1);
    p.dispose();
  });

  test('createDebt op drains to a debt doc', () async {
    final sync = OfflineSyncService();
    sync.firestore = fake;
    ConnectivityService().setOnlineForTest(true);
    sync.dispose();
    await OfflineCacheService().queueOperation({
      'opId': 'debt-op-1',
      'type': 'createDebt',
      'docId': 'debt-doc-1',
      'payload': Debt(
        id: 'debt-doc-1',
        collectorId: 'c1',
        collectorName: 'Alice',
        purchaseId: 'tx-1',
        totalAmount: 1000,
        coveredAmount: 400,
        forgivenAmount: 600,
        status: DebtStatus.open,
        createdAt: DateTime.now(),
        createdBy: 'u1',
      ).toFirestore(),
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    await sync.syncPendingOperations();
    final doc = await fake.collection('debts').doc('debt-doc-1').get();
    expect(doc.data()?['forgivenAmount'], 600);
    expect(doc.data()?['status'], 'open');
    expect(OfflineCacheService().getPendingOperations(), isEmpty);
    sync.dispose();
  });
}
