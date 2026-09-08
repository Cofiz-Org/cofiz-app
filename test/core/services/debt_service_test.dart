import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:cofiz/core/services/debt_service.dart';
import 'package:cofiz/core/services/offline_cache_service.dart';
import 'package:cofiz/core/services/offline_sync_service.dart';

void main() {
  late Directory tempDir;
  late FakeFirebaseFirestore fs;
  late DebtService svc;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('debt_service_test');
    await OfflineCacheService().initialize(path: tempDir.path);
  });

  tearDownAll(() async {
    await OfflineCacheService().clearAllCache();
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  setUp(() async {
    fs = FakeFirebaseFirestore();
    svc = DebtService(firestore: fs);
    OfflineSyncService().firestore = fs;
    await OfflineCacheService().clearAllCache();
  });

  Future<void> drain() async {
    final sync = OfflineSyncService();
    sync.firestore = fs;
    for (var i = 0; i < 40; i++) {
      await sync.syncPendingOperations();
      if (OfflineCacheService().getPendingOperations().isEmpty) break;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    sync.dispose();
  }

  test('createDebtFromPurchase queues and drains to a doc', () async {
    final d = await svc.createDebtFromPurchase(
      collectorId: 'c1',
      collectorName: 'Alice',
      purchaseId: 'p1',
      totalAmount: 1000,
      coveredAmount: 400,
      forgivenAmount: 600,
      createdBy: 'u1',
    );
    expect(d.forgivenAmount, 600);
    expect(OfflineCacheService().getPendingOperations(), isNotEmpty);
    await drain();
    final snap = await fs.collection('debts').get();
    expect(snap.docs.length, 1);
    expect(OfflineCacheService().getPendingOperations(), isEmpty);
  });

  test('markPaid flips status and paidAt', () async {
    final d = await svc.createDebtFromPurchase(
      collectorId: 'c1',
      collectorName: 'A',
      purchaseId: 'p1',
      totalAmount: 100,
      coveredAmount: 50,
      forgivenAmount: 50,
      createdBy: 'u1',
    );
    await drain();
    await svc.markPaid(d.id);
    final snap = await fs.collection('debts').doc(d.id).get();
    expect(snap.data()!['status'], 'paid');
    expect(snap.data()!['paidAt'], isNotNull);
  });

  test('getOpenDebtsTotal sums forgivenAmount where status=open', () async {
    await svc.createDebtFromPurchase(collectorId: 'c1', collectorName: 'A', purchaseId: 'p1', totalAmount: 100, coveredAmount: 50, forgivenAmount: 50, createdBy: 'u1');
    await svc.createDebtFromPurchase(collectorId: 'c2', collectorName: 'B', purchaseId: 'p2', totalAmount: 200, coveredAmount: 100, forgivenAmount: 100, createdBy: 'u1');
    await drain();
    expect(await svc.getOpenDebtsTotal(), 150);
  });
}
