import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/debt_model.dart';
import '../utils/date_formatter.dart';
import 'offline_cache_service.dart';
import 'offline_sync_service.dart';

class DebtPage {
  final List<Debt> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  DebtPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}

class DebtService {
  DebtService({FirebaseFirestore? firestore}) : _fs = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _fs;

  CollectionReference<Map<String, dynamic>> get _col => _fs.collection('debts');

  Future<Debt> createDebtFromPurchase({
    required String collectorId,
    required String collectorName,
    required String purchaseId,
    required double totalAmount,
    required double coveredAmount,
    required double forgivenAmount,
    required String createdBy,
    String? notes,
    String source = 'purchase',
    String creditorName = '',
  }) async {
    final ref = _col.doc();
    final debt = Debt(
      id: ref.id,
      collectorId: collectorId,
      collectorName: collectorName,
      source: source,
      purchaseId: purchaseId,
      totalAmount: totalAmount,
      coveredAmount: coveredAmount,
      forgivenAmount: forgivenAmount,
      status: DebtStatus.open,
      createdAt: DateTime.now(),
      createdBy: createdBy,
      notes: notes,
      creditorName: creditorName,
    );
    await OfflineCacheService().queueOperation({
      'opId': ref.id,
      'type': 'createDebt',
      'docId': ref.id,
      'payload': debt.toFirestore(),
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    unawaited(OfflineSyncService().syncNow());
    return debt;
  }

  Future<void> markPaid(String debtId) async {
    try {
      await _col.doc(debtId).update({
        'status': DebtStatus.paid.name,
        'paidAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      await OfflineCacheService().queueOperation({
        'opId': 'markPaid:$debtId',
        'type': 'markDebtPaid',
        'docId': debtId,
        'payload': {
          'status': DebtStatus.paid.name,
          'paidAt': DateTime.now().millisecondsSinceEpoch,
        },
        'queuedAt': DateTime.now().toIso8601String(),
        'attempts': 0,
      });
      unawaited(OfflineSyncService().syncNow());
    }
  }

  Stream<List<Debt>> streamDebtsForCollector(String collectorId) {
    return _col.where('collectorId', isEqualTo: collectorId).orderBy('createdAt', descending: true).snapshots().map(_decodeDocs);
  }

  Stream<List<Debt>> streamAllOpenDebts() {
    return _col.where('status', isEqualTo: DebtStatus.open.name).orderBy('createdAt', descending: true).snapshots().map(_decodeDocs);
  }

  Stream<List<Debt>> streamAllDebts() {
    return _col.orderBy('createdAt', descending: true).snapshots().map(_decodeDocs);
  }

  Future<List<Debt>> getAllDebts() async {
    final s = await _col.orderBy('createdAt', descending: true).get();
    return _decodeDocs(s);
  }

  Future<DebtPage> getDebtsPage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query =
          _col.orderBy('createdAt', descending: true).limit(pageSize);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      return DebtPage(
        items: _decodeDocs(snapshot),
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error fetching debts page: $e');
      return DebtPage(items: const [], lastDoc: null, hasMore: false);
    }
  }

  static List<Debt> _decodeDocs(QuerySnapshot<Map<String, dynamic>> s) {
    final out = <Debt>[];
    for (final d in s.docs) {
      try {
        out.add(Debt.fromFirestore(d));
      } catch (_) {}
    }
    return out;
  }

  Future<double> getOpenDebtsTotal() async {
    final s = await _col.where('status', isEqualTo: DebtStatus.open.name).get();
    return s.docs.map((d) => (d.data()['forgivenAmount'] as num).toDouble()).fold<double>(0.0, (a, b) => a + b);
  }

  Future<double> getOpenDebtsTotalForToday() async {
    final dayStart = DateFormatter.addisDayStart();
    final s = await _col
        .where('status', isEqualTo: DebtStatus.open.name)
        .where('createdAt', isGreaterThanOrEqualTo: dayStart.millisecondsSinceEpoch)
        .get();
    return s.docs.map((d) => (d.data()['forgivenAmount'] as num).toDouble()).fold<double>(0.0, (a, b) => a + b);
  }

  Future<void> deleteDebts(List<String> ids) async {
    if (ids.isEmpty) return;
    var batch = _fs.batch();
    var count = 0;
    for (final id in ids) {
      batch.delete(_col.doc(id));
      count++;
      if (count >= 400) {
        await batch.commit();
        batch = _fs.batch();
        count = 0;
      }
    }
    if (count > 0) await batch.commit();
  }

  static const String _collectorWipeFlag = 'collector_debt_wipe_v1';

  Future<int> wipeLegacyCollectorDebtsOnce() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_collectorWipeFlag) == true) return 0;
      final all = await getAllDebts();
      final ids = all
          .where((d) =>
              d.collectorId != Debt.companyCollectorId &&
              d.status != DebtStatus.paid)
          .map((d) => d.id)
          .toList();
      if (ids.isNotEmpty) await deleteDebts(ids);
      await prefs.setBool(_collectorWipeFlag, true);
      return ids.length;
    } catch (_) {
      return 0;
    }
  }

  Future<List<Debt>> getDebtsForCollector(String collectorId) async {
    final s = await _col.where('collectorId', isEqualTo: collectorId).orderBy('createdAt', descending: true).get();
    return s.docs.map(Debt.fromFirestore).toList();
  }
}
