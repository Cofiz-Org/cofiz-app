import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/income_record_model.dart';
import '../utils/date_formatter.dart';
import 'offline_cache_service.dart';
import 'offline_sync_service.dart';


class IncomePage {
  final List<IncomeRecord> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  IncomePage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}

class IncomeService {
  static const String _collectionName = 'income_records';
  static const String _settingsDoc = 'saleCategories';
  static const String _settingsCollection = 'settings';

  static const List<String> defaultSaleCategories = [
    'Coffee Beans',
    'Processed Coffee',
    'Equipment',
    'Byproducts',
    'Other',
  ];

  final FirebaseFirestore _firestore;

  IncomeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _categoriesRef =>
      _firestore.collection(_settingsCollection).doc(_settingsDoc);

  Stream<List<IncomeRecord>> getIncomeStream() {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  Stream<List<IncomeRecord>> getIncomeForViewerStream(String viewerId) {
    return _firestore
        .collection(_collectionName)
        .where('viewerId', isEqualTo: viewerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  
  Stream<List<IncomeRecord>> getIncomePageStream({int limit = 20}) {
    return _firestore
        .collection(_collectionName)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  
  Future<IncomePage> getIncomePage({
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
          .toList();
      return IncomePage(
        items: records,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error fetching income page: $e');
      return IncomePage(items: const [], lastDoc: null, hasMore: false);
    }
  }

  
  Stream<List<IncomeRecord>> getIncomeForViewerPageStream(String viewerId,
      {int limit = 20}) {
    return _firestore
        .collection(_collectionName)
        .where('viewerId', isEqualTo: viewerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
            .toList());
  }

  
  Future<IncomePage> getIncomeForViewerPage(
    String viewerId, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .where('viewerId', isEqualTo: viewerId)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final records = snapshot.docs
          .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
          .toList();
      return IncomePage(
        items: records,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error fetching viewer income page: $e');
      return IncomePage(items: const [], lastDoc: null, hasMore: false);
    }
  }

  
  Future<List<IncomeRecord>> getIncomeForDay(DateTime day) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final startTimestamp = startOfDay.millisecondsSinceEpoch;
    final endTimestamp =
        startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch;
    try {
      final snap = await _firestore
          .collection(_collectionName)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (_) {
      
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final cached = OfflineCacheService().getCachedIncome() ?? const [];
      return cached
          .where((r) =>
              !r.createdAt.isBefore(dayStart) && r.createdAt.isBefore(dayEnd))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  
  Future<List<IncomeRecord>> getAllIncome() async {
    try {
      final snap = await _firestore
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs
          .map((doc) => IncomeRecord.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      
      
      return OfflineCacheService().getCachedIncome() ?? const [];
    }
  }

  
  
  Future<double?> getIncomeTotal({String? viewerId}) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(_collectionName);
      if (viewerId != null) {
        query = query.where('viewerId', isEqualTo: viewerId);
      }
      final snapshot = await query.aggregate(sum('amount')).get();
      return snapshot.getSum('amount') ?? 0.0;
    } catch (e) {
      debugPrint('Error fetching income total: $e');
      return null;
    }
  }

  
  
  Future<double?> getIncomeTotalByKind(IncomeKind kind,
      {String? viewerId}) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .where('kind', isEqualTo: kind.name);
      if (viewerId != null) {
        query = query.where('viewerId', isEqualTo: viewerId);
      }
      final snapshot = await query.aggregate(sum('amount')).get();
      return snapshot.getSum('amount') ?? 0.0;
    } catch (e) {
      debugPrint('Error fetching income kind total: $e');
      return null;
    }
  }

  
  
  Future<double?> getIncomeTodayTotal({String? viewerId}) async {
    try {
      final start = DateFormatter.addisDayStart();
      final end = start.add(const Duration(days: 1));
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .where('createdAt',
              isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
          .where('createdAt', isLessThan: end.millisecondsSinceEpoch);
      if (viewerId != null) {
        query = query.where('viewerId', isEqualTo: viewerId);
      }
      final snapshot = await query.aggregate(sum('amount')).get();
      return snapshot.getSum('amount') ?? 0.0;
    } catch (e) {
      debugPrint('Error fetching today income total: $e');
      return null;
    }
  }

  
  
  Future<double?> getIncomeTodayTotalByKind(IncomeKind kind,
      {String? viewerId}) async {
    try {
      final start = DateFormatter.addisDayStart();
      final end = start.add(const Duration(days: 1));
      Query<Map<String, dynamic>> query = _firestore
          .collection(_collectionName)
          .where('kind', isEqualTo: kind.name)
          .where('createdAt',
              isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
          .where('createdAt', isLessThan: end.millisecondsSinceEpoch);
      if (viewerId != null) {
        query = query.where('viewerId', isEqualTo: viewerId);
      }
      final snapshot = await query.aggregate(sum('amount')).get();
      return snapshot.getSum('amount') ?? 0.0;
    } catch (e) {
      debugPrint('Error fetching today income kind total: $e');
      return null;
    }
  }

  
  
  Future<int?> getIncomeCount({String? viewerId}) async {
    try {
      Query<Map<String, dynamic>> query =
          _firestore.collection(_collectionName);
      if (viewerId != null) {
        query = query.where('viewerId', isEqualTo: viewerId);
      }
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error fetching income count: $e');
      return null;
    }
  }

  Future<String?> addIncome(IncomeRecord record) async {
    final opId = const Uuid().v4();
    await OfflineCacheService().queueOperation({
      'opId': opId,
      'type': 'createIncome',
      'docId': opId,
      'payload': record.toFirestore(),
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    final cached = OfflineCacheService().getCachedIncome() ?? [];
    await OfflineCacheService()
        .cacheIncome([...cached, record.copyWith(id: opId)]);
    debugPrint(
        '[IncomeService] addIncome opId=$opId queued+cached, syncing...');
    unawaited(OfflineSyncService().syncNow());
    return opId;
  }

  Future<bool> updateIncome(IncomeRecord record) async {
    await OfflineCacheService().queueOperation({
      'opId': record.id,
      'type': 'updateIncome',
      'docId': record.id,
      'payload': record.toFirestore(),
      'attempts': 0,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    final cached = OfflineCacheService().getCachedIncome() ?? [];
    await OfflineCacheService().cacheIncome([
      for (final r in cached)
        if (r.id != record.id) r,
      record
    ]);
    unawaited(OfflineSyncService().syncNow());
    return true;
  }

  Future<bool> deleteIncome(String id) async {
    await OfflineCacheService().queueOperation({
      'opId': id,
      'type': 'deleteIncome',
      'docId': id,
      'attempts': 0,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    await OfflineCacheService().removeCachedIncome(id);
    unawaited(OfflineSyncService().syncNow());
    return true;
  }

  Future<void> initializeDefaultSaleCategories() async {
    try {
      final snap = await _categoriesRef.get();
      if (!snap.exists || snap.data()?['categories'] == null) {
        await _categoriesRef.set({'categories': defaultSaleCategories}, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Error initializing sale categories: $e');
    }
  }

  Stream<List<String>> getSaleCategoriesStream() {
    return _categoriesRef.snapshots().map((snap) {
      final categories = (snap.data()?['categories'] as List?)?.cast<String>();
      if (categories == null || categories.isEmpty) {
        return defaultSaleCategories;
      }
      return categories;
    });
  }

  Future<List<String>> getSaleCategories() async {
    try {
      final snap = await _categoriesRef.get();
      final categories = (snap.data()?['categories'] as List?)?.cast<String>();
      if (categories == null || categories.isEmpty) {
        return defaultSaleCategories;
      }
      return categories;
    } catch (e) {
      return defaultSaleCategories;
    }
  }

  Future<bool> addSaleCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return false;
    try {
      final current = await getSaleCategories();
      if (current.contains(trimmed)) return true;
      await _categoriesRef.set({
        'categories': FieldValue.arrayUnion([trimmed]),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error adding sale category: $e');
      return false;
    }
  }

  Future<bool> removeSaleCategory(String name) async {
    if (defaultSaleCategories.contains(name)) return false;
    try {
      final snap = await _categoriesRef.get();
      if (!snap.exists) return false;
      await _categoriesRef.update({
        'categories': FieldValue.arrayRemove([name]),
      });
      return true;
    } catch (e) {
      debugPrint('Error removing sale category: $e');
      return false;
    }
  }
}
