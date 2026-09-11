import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/transaction_model.dart';
import '../models/worker_model.dart';
import '../utils/date_formatter.dart';
import '../config/cloudinary_config.dart';
import '../utils/receipt_image_utils.dart';
import '../utils/transaction_balance.dart' as tb;
export '../utils/transaction_balance.dart' show TransactionLockedException;
import 'connectivity_service.dart';
import 'offline_cache_service.dart';
import 'offline_sync_service.dart';


class TransactionPage {
  final List<MoneyTransaction> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDoc;
  final bool hasMore;

  TransactionPage({
    required this.items,
    required this.lastDoc,
    required this.hasMore,
  });
}


class TransactionService {
  final FirebaseFirestore _firestore;

  TransactionService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;
  static const String _transactionsCollection = 'transactions';

  
  
  Stream<List<MoneyTransaction>> getWorkerTransactionsStream(
    String workerId, {
    int limit = 20,
  }) {
    return _firestore
        .collection(_transactionsCollection)
        .where('workerId', isEqualTo: workerId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return MoneyTransaction.fromFirestore(doc.data(), doc.id);
      }).toList();
    });
  }

  
  Future<TransactionPage> getWorkerTransactionsPage(
    String workerId, {
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int pageSize = 20,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection(_transactionsCollection)
          .where('workerId', isEqualTo: workerId)
          .orderBy('createdAt', descending: true)
          .limit(pageSize);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.get();
      final transactions = snapshot.docs
          .map((doc) => MoneyTransaction.fromFirestore(doc.data(), doc.id))
          .toList();
      return TransactionPage(
        items: transactions,
        lastDoc: snapshot.docs.isNotEmpty ? snapshot.docs.last : null,
        hasMore: snapshot.docs.length == pageSize,
      );
    } catch (e) {
      debugPrint('Error fetching worker transactions page: $e');
      return TransactionPage(items: const [], lastDoc: null, hasMore: false);
    }
  }

  
  
  
  Future<List<MoneyTransaction>> getWorkerTransactionsForDay(
    String workerId,
    DateTime day,
  ) async {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final startTimestamp = startOfDay.millisecondsSinceEpoch;
    final endTimestamp =
        startOfDay.add(const Duration(days: 1)).millisecondsSinceEpoch;

    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('workerId', isEqualTo: workerId)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .where('createdAt', isLessThan: endTimestamp)
          .orderBy('createdAt', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => MoneyTransaction.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      
      
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = dayStart.add(const Duration(days: 1));
      final cached =
          OfflineCacheService().getCachedWorkerTransactions(workerId);
      return cached
          .where((t) =>
              !t.createdAt.isBefore(dayStart) && t.createdAt.isBefore(dayEnd))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
  }

  
  Future<int> getWorkerTransactionCount(String workerId) async {
    try {
      final snap = await _firestore
          .collection(_transactionsCollection)
          .where('workerId', isEqualTo: workerId)
          .count()
          .get();
      return snap.count ?? 0;
    } catch (e) {
      debugPrint('Error counting worker transactions: $e');
      return 0;
    }
  }

  
  Stream<List<MoneyTransaction>> getAllTransactionsStream() {
    return _firestore
        .collection(_transactionsCollection)
        .snapshots()
        .map((snapshot) {
      final transactions = snapshot.docs.map((doc) {
        return MoneyTransaction.fromFirestore(doc.data(), doc.id);
      }).toList();

      
      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    });
  }

  
  Future<List<MoneyTransaction>> getAllTransactions() async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => MoneyTransaction.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching all transactions: $e');
      return [];
    }
  }

  
  
  
  Future<String?> addTransaction(
    MoneyTransaction transaction, {
    String? localReceiptPath,
  }) async {
    if (transaction.amount <= 0) throw 'Amount must be greater than 0';
    if (ConnectivityService().isOnline &&
        transaction.type.toLowerCase() == 'return') {
      try {
        final workerDoc = await _firestore
            .collection('workers')
            .doc(transaction.workerId)
            .get();

        if (!workerDoc.exists) {
          throw 'Collector not found';
        }

        final currentBalance =
            (workerDoc.data()?['currentBalance'] ?? 0.0).toDouble();

        if (transaction.amount > currentBalance) {
          throw 'Insufficient balance. Available: ETB ${currentBalance.toStringAsFixed(2)}, Required: ETB ${transaction.amount.toStringAsFixed(2)}';
        }
      } catch (e) {
        if (e is String) rethrow; 
        
        
        
        final projected = _projectedBalance(transaction.workerId);
        if (projected != null && transaction.amount > projected) {
          throw 'Insufficient balance. Available: ETB ${projected.toStringAsFixed(2)}, Required: ETB ${transaction.amount.toStringAsFixed(2)}';
        }
      }
    } else if (!ConnectivityService().isOnline &&
        transaction.type.toLowerCase() == 'return') {
      final projected = _projectedBalance(transaction.workerId);
      if (projected != null && transaction.amount > projected) {
        throw 'Insufficient balance. Available: ETB ${projected.toStringAsFixed(2)}, Required: ETB ${transaction.amount.toStringAsFixed(2)}';
      }
    }
    final opId = const Uuid().v4();
    final docId = opId;
    await OfflineCacheService().queueOperation({
      'opId': opId,
      'type': 'createTransaction',
      'docId': docId,
      'workerId': transaction.workerId,
      'workerName': transaction.workerName,
      'transactionType': transaction.type,
      'amount': transaction.amount,
      'notes': transaction.notes,
      'receiptUrl': transaction.receiptUrl,
      'localReceiptPath': localReceiptPath,
      'createdAt': transaction.createdAt.millisecondsSinceEpoch,
      'createdBy': transaction.createdBy,
      'coffeeType': transaction.coffeeType,
      'coffeeWeight': transaction.coffeeWeight,
      'pricePerKg': transaction.pricePerKg,
      'commissionAmount': transaction.commissionAmount,
      'forgivenAmount': transaction.forgivenAmount,
      'dailyPriceAtSale': transaction.dailyPriceAtSale,
      'aboveDailyPrice': transaction.aboveDailyPrice,
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    
    final cached = OfflineCacheService().getCachedTransactions() ?? [];
    final optimistic = MoneyTransaction(
      id: docId,
      workerId: transaction.workerId,
      workerName: transaction.workerName,
      type: transaction.type,
      amount: transaction.amount,
      notes: transaction.notes,
      receiptUrl: transaction.receiptUrl,
      createdAt: transaction.createdAt,
      createdBy: transaction.createdBy,
      approved: transaction.approved,
      coffeeType: transaction.coffeeType,
      coffeeWeight: transaction.coffeeWeight,
      pricePerKg: transaction.pricePerKg,
      commissionAmount: transaction.commissionAmount,
      fromWorkerId: transaction.fromWorkerId,
      toWorkerId: transaction.toWorkerId,
      fromWorkerName: transaction.fromWorkerName,
      toWorkerName: transaction.toWorkerName,
      transferId: transaction.transferId,
      transferRole: transaction.transferRole,
      dailyPriceAtSale: transaction.dailyPriceAtSale,
      aboveDailyPrice: transaction.aboveDailyPrice,
    );
    await OfflineCacheService().cacheTransactions([...cached, optimistic]);
    
    
    unawaited(_mirrorWorkerCache(optimistic.workerId));
    unawaited(OfflineSyncService().syncNow());
    return docId;
  }

  
  
  Future<void> _mirrorWorkerCache(String workerId) async {
    try {
      final all = OfflineCacheService().getCachedTransactions() ?? [];
      final forWorker = all.where((t) => t.workerId == workerId).toList();
      await OfflineCacheService().cacheWorkerTransactions(workerId, forWorker);
    } catch (_) {}
  }

  
  Future<String?> addTransfer({
    required String fromWorkerId,
    required String fromWorkerName,
    required String toWorkerId,
    required String toWorkerName,
    required double amount,
    required String createdBy,
    String? notes,
  }) async {
    if (amount <= 0) {
      throw 'Amount must be greater than 0';
    }

    final opId = const Uuid().v4();
    final transferId = opId;
    final senderDocId = opId;
    final receiverDocId = '${opId}_r';
    final now = DateTime.now();

    await OfflineCacheService().queueOperation({
      'opId': opId,
      'type': 'createTransfer',
      'transferId': transferId,
      'senderDocId': senderDocId,
      'receiverDocId': receiverDocId,
      'fromWorkerId': fromWorkerId,
      'fromWorkerName': fromWorkerName,
      'toWorkerId': toWorkerId,
      'toWorkerName': toWorkerName,
      'amount': amount,
      'createdAt': now.millisecondsSinceEpoch,
      'createdBy': createdBy,
      'notes': notes,
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });

    
    final cached = OfflineCacheService().getCachedTransactions() ?? [];
    final senderTx = MoneyTransaction(
      id: senderDocId,
      workerId: fromWorkerId,
      workerName: fromWorkerName,
      type: 'transfer',
      amount: amount,
      notes: notes,
      createdAt: now,
      createdBy: createdBy,
      approved: false,
      fromWorkerId: fromWorkerId,
      toWorkerId: toWorkerId,
      fromWorkerName: fromWorkerName,
      toWorkerName: toWorkerName,
      transferId: transferId,
      transferRole: 'sender',
    );
    final receiverTx = MoneyTransaction(
      id: receiverDocId,
      workerId: toWorkerId,
      workerName: toWorkerName,
      type: 'transfer',
      amount: amount,
      notes: notes,
      createdAt: now,
      createdBy: createdBy,
      approved: false,
      fromWorkerId: fromWorkerId,
      toWorkerId: toWorkerId,
      fromWorkerName: fromWorkerName,
      toWorkerName: toWorkerName,
      transferId: transferId,
      transferRole: 'receiver',
    );
    await OfflineCacheService()
        .cacheTransactions([...cached, senderTx, receiverTx]);
    unawaited(_mirrorWorkerCache(senderTx.workerId));
    unawaited(_mirrorWorkerCache(receiverTx.workerId));
    unawaited(OfflineSyncService().syncNow());
    return transferId;
  }

  
  Future<void> approveTransaction(String transactionId) async {
    await OfflineCacheService().queueOperation({
      'opId': const Uuid().v4(),
      'type': 'approveTransaction',
      'transactionId': transactionId,
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    unawaited(OfflineSyncService().syncNow());
  }

  
  Future<void> approveAllForWorker(String workerId) async {
    await OfflineCacheService().queueOperation({
      'opId': const Uuid().v4(),
      'type': 'approveAll',
      'workerId': workerId,
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    unawaited(OfflineSyncService().syncNow());
  }

  
  Future<void> approveTransfer(String transferId) async {
    await OfflineCacheService().queueOperation({
      'opId': const Uuid().v4(),
      'type': 'approveTransfer',
      'transferId': transferId,
      'queuedAt': DateTime.now().toIso8601String(),
      'attempts': 0,
    });
    unawaited(OfflineSyncService().syncNow());
  }

  
  
  
  Future<void> deleteTransfer(
    String transferId, {
    String? overrideReason,
  }) async {
    final cached = OfflineCacheService().getCachedTransactions();
    if (cached != null) {
      final matches = cached.where((t) => t.transferId == transferId).toList();
      for (final tx in matches) {
        _enforceLock(tx, overrideReason: overrideReason, action: 'delete');
      }
    }
    await OfflineCacheService().queueOperation({
      'opId': transferId,
      'type': 'deleteTransfer',
      'transferId': transferId,
      'overrideReason': overrideReason,
      'attempts': 0,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    final cachedList = OfflineCacheService().getCachedTransactions() ?? [];
    final affectedWorkers = cached
            ?.where((t) => t.transferId == transferId)
            .map((t) => t.workerId)
            .toSet() ??
        {};
    await OfflineCacheService().cacheTransactions(
        cachedList.where((t) => t.transferId != transferId).toList());
    for (final w in affectedWorkers) {
      unawaited(_mirrorWorkerCache(w));
    }
    unawaited(OfflineSyncService().syncNow());
  }

  
  
  
  Future<void> updateTransaction(
    MoneyTransaction transaction, {
    String? overrideReason,
    String? localReceiptPath,
  }) async {
    final cached = OfflineCacheService().getCachedTransactions();
    MoneyTransaction? old;
    if (cached != null) {
      try {
        old = cached.firstWhere((t) => t.id == transaction.id);
      } catch (_) {}
    }
    if (old != null) {
      _enforceLock(old, overrideReason: overrideReason, action: 'edit');
      if (old.isTransfer || transaction.isTransfer) {
        throw 'Transfers cannot be edited.';
      }
    } else if (transaction.isTransfer) {
      throw 'Transfers cannot be edited.';
    }
    if (!ConnectivityService().isOnline) {
      if (transaction.type.toLowerCase() == 'return') {
        final projected = _projectedBalance(transaction.workerId);
        if (projected != null) {
          double available = projected;
          if (old != null && old.workerId == transaction.workerId) {
            available -= _numericBalanceDelta(old, 1);
          }
          if (transaction.amount > available) {
            throw 'Insufficient balance. Available: ETB ${available.toStringAsFixed(2)}, Required: ETB ${transaction.amount.toStringAsFixed(2)}';
          }
        }
      }
    } else {
      
      if (transaction.type.toLowerCase() == 'return') {
        
        try {
          final workerDoc = await _firestore
              .collection('workers')
              .doc(transaction.workerId)
              .get();
          if (workerDoc.exists) {
            final currentBalance =
                (workerDoc.data()?['currentBalance'] ?? 0.0).toDouble();
            
            
            final oldEffect =
                old != null && old.type.toLowerCase() == 'distribution'
                    ? old.amount
                    : 0.0;
            final projectedBalance =
                currentBalance + oldEffect - transaction.amount;
            if (projectedBalance < 0) {
              throw 'Insufficient balance. Available: ETB ${projectedBalance.toStringAsFixed(2)}, Required: ETB ${transaction.amount.toStringAsFixed(2)}';
            }
          }
        } catch (e) {
          if (e is String && e.contains('Insufficient')) rethrow;
        }
      }
    }
    await OfflineCacheService().queueOperation({
      'opId': transaction.id,
      'type': 'updateTransaction',
      'docId': transaction.id,
      'payload': transaction.toFirestore(),
      
      
      
      if (old != null) 'previous': old.toFirestore(),
      'overrideReason': overrideReason,
      'localReceiptPath': localReceiptPath,
      'attempts': 0,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    final cachedList = OfflineCacheService().getCachedTransactions() ?? [];
    await OfflineCacheService().cacheTransactions([
      for (final t in cachedList)
        if (t.id != transaction.id) t,
      transaction,
    ]);
    unawaited(_mirrorWorkerCache(transaction.workerId));
    unawaited(OfflineSyncService().syncNow());
  }

  
  
  
  Future<void> deleteTransaction(
    String transactionId, {
    String? overrideReason,
  }) async {
    final cached = OfflineCacheService().getCachedTransactions();
    MoneyTransaction? tx;
    if (cached != null) {
      try {
        tx = cached.firstWhere((t) => t.id == transactionId);
      } catch (_) {}
    }
    if (tx != null) {
      _enforceLock(tx, overrideReason: overrideReason, action: 'delete');
      if (tx.isTransfer) {
        throw 'Use transfer delete for transfers.';
      }
    }
    await OfflineCacheService().queueOperation({
      'opId': transactionId,
      'type': 'deleteTransaction',
      'docId': transactionId,
      if (tx != null) 'previous': tx.toFirestore(),
      'overrideReason': overrideReason,
      'attempts': 0,
      'queuedAt': DateTime.now().toIso8601String(),
    });
    final cachedList = OfflineCacheService().getCachedTransactions() ?? [];
    await OfflineCacheService().cacheTransactions(
        cachedList.where((t) => t.id != transactionId).toList());
    if (tx != null) unawaited(_mirrorWorkerCache(tx.workerId));
    unawaited(OfflineSyncService().syncNow());
  }

  
  
  void _enforceLock(
    MoneyTransaction transaction, {
    required String? overrideReason,
    required String action,
  }) =>
      tb.enforceTransactionLock(transaction,
          overrideReason: overrideReason, action: action);

  double _numericBalanceDelta(MoneyTransaction t, int direction) {
    final mult = direction.toDouble();
    switch (t.type.toLowerCase()) {
      case 'distribution':
        return t.amount * mult;
      case 'return':
        return -t.amount * mult;
      case 'purchase':
        return -t.amount * mult;
      case 'transfer':
        final eff = t.isTransferSender ? -1.0 : 1.0;
        return t.amount * mult * eff;
      default:
        return 0;
    }
  }

  
  
  double? _projectedBalance(String workerId) {
    double base = 0;
    Worker? w =
        OfflineCacheService().getCachedWorkerProfile(expectedId: workerId);
    if (w == null) {
      final workers = OfflineCacheService().getCachedWorkers();
      if (workers != null) {
        for (final worker in workers) {
          if (worker.id == workerId) {
            w = worker;
            break;
          }
        }
      }
    }
    if (w == null) return null;
    base = w.currentBalance;
    final pending = OfflineCacheService().getPendingOperations();
    final cachedTxs = OfflineCacheService().getCachedTransactions() ?? [];
    final txMap = {for (final t in cachedTxs) t.id: t};
    for (final op in pending) {
      final type = op['type'] as String? ?? '';
      try {
        if (type == 'createTransaction') {
          if (op['workerId'] != workerId) continue;
          final mt = MoneyTransaction(
            id: op['docId'] as String? ?? op['opId'] as String,
            workerId: op['workerId'] as String,
            workerName: op['workerName'] as String? ?? '',
            type: op['transactionType'] as String? ?? 'distribution',
            amount: (op['amount'] as num).toDouble(),
            createdAt: op['createdAt'] != null
                ? DateTime.fromMillisecondsSinceEpoch(op['createdAt'] as int)
                : DateTime.now(),
            createdBy: op['createdBy'] as String? ?? '',
            commissionAmount: (op['commissionAmount'] as num?)?.toDouble(),
            forgivenAmount: (op['forgivenAmount'] as num?)?.toDouble(),
            transferId: op['transferId'] as String?,
            transferRole: op['transferRole'] as String?,
          );
          base += _numericBalanceDelta(mt, 1);
        } else if (type == 'deleteTransaction') {
          final docId = op['docId'] as String?;
          
          
          final prevMap = op['previous'] as Map<String, dynamic>?;
          MoneyTransaction? tx;
          if (prevMap != null) {
            try {
              tx = MoneyTransaction.fromFirestore(
                  Map<String, dynamic>.from(prevMap), docId ?? '');
            } catch (_) {}
          }
          tx ??= txMap[docId];
          if (tx == null || tx.workerId != workerId) continue;
          base += _numericBalanceDelta(tx, -1);
        } else if (type == 'updateTransaction') {
          final docId = op['docId'] as String?;
          final prevMap = op['previous'] as Map<String, dynamic>?;
          MoneyTransaction? old;
          if (prevMap != null) {
            try {
              old = MoneyTransaction.fromFirestore(
                  Map<String, dynamic>.from(prevMap), docId ?? '');
            } catch (_) {}
          }
          old ??= txMap[docId];
          final payload = op['payload'] as Map<String, dynamic>?;
          if (payload == null) continue;
          MoneyTransaction newTx;
          try {
            newTx = MoneyTransaction.fromFirestore(
                Map<String, dynamic>.from(payload), docId!);
          } catch (_) {
            continue;
          }
          if (old != null && old.workerId == workerId) {
            base += _numericBalanceDelta(old, -1);
          }
          if (newTx.workerId == workerId) {
            base += _numericBalanceDelta(newTx, 1);
          }
        } else if (type == 'createTransfer') {
          final amt = (op['amount'] as num?)?.toDouble() ?? 0;
          if (op['fromWorkerId'] == workerId) base -= amt;
          if (op['toWorkerId'] == workerId) base += amt;
        } else if (type == 'deleteTransfer') {
          final tid = op['transferId'] as String? ?? op['opId'] as String?;
          if (tid == null) continue;
          for (final t in cachedTxs.where((t) => t.transferId == tid)) {
            if (t.workerId != workerId) continue;
            base += _numericBalanceDelta(t, -1);
          }
        }
      } catch (_) {}
    }
    return base;
  }



  
  Future<List<MoneyTransaction>> getRecentTransactions({int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .limit(limit)
          .get();

      final transactions = snapshot.docs
          .map((doc) => MoneyTransaction.fromFirestore(doc.data(), doc.id))
          .toList();

      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    } catch (e) {
      debugPrint('Error getting recent transactions: $e');
      return [];
    }
  }

  
  Future<List<MoneyTransaction>> getWorkerTransactions(
    String workerId, {
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('workerId', isEqualTo: workerId)
          .limit(limit)
          .get();

      final transactions = snapshot.docs
          .map((doc) => MoneyTransaction.fromFirestore(doc.data(), doc.id))
          .toList();

      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    } catch (e) {
      debugPrint('Error getting worker transactions: $e');
      return [];
    }
  }

  
  Future<List<MoneyTransaction>> getTransactionsByType(String type) async {
    try {
      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('type', isEqualTo: type)
          .get();

      final transactions = snapshot.docs
          .map((doc) => MoneyTransaction.fromFirestore(doc.data(), doc.id))
          .toList();

      transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return transactions;
    } catch (e) {
      debugPrint('Error getting transactions by type: $e');
      return [];
    }
  }

  
  Future<Map<String, double>> getTodayTotals() async {
    try {
      final startOfDay = DateFormatter.addisDayStart();
      final startTimestamp = startOfDay.millisecondsSinceEpoch;

      final snapshot = await _firestore
          .collection(_transactionsCollection)
          .where('createdAt', isGreaterThanOrEqualTo: startTimestamp)
          .get();

      double totalDistributed = 0;
      double totalReturned = 0;
      double totalPurchased = 0;

      for (var doc in snapshot.docs) {
        final transaction = MoneyTransaction.fromFirestore(doc.data(), doc.id);
        switch (transaction.type.toLowerCase()) {
          case 'distribution':
            totalDistributed += transaction.amount;
            break;
          case 'return':
            totalReturned += transaction.amount;
            break;
          case 'purchase':
            totalPurchased += transaction.amount;
            break;
        }
      }

      return {
        'distributed': totalDistributed,
        'returned': totalReturned,
        'purchased': totalPurchased,
      };
    } catch (e) {
      debugPrint('Error getting today totals: $e');
      return {
        'distributed': 0.0,
        'returned': 0.0,
        'purchased': 0.0,
      };
    }
  }

  Future<String?> uploadReceipt(String filePath) async {
    try {
      final compressedBytes = await ReceiptImageUtils.compress(filePath);
      if (compressedBytes == null || compressedBytes.isEmpty) return null;

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(CloudinaryConfig.uploadEndpoint),
      )
        ..fields['upload_preset'] = CloudinaryConfig.uploadPreset
        ..fields['folder'] = CloudinaryConfig.folder
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          compressedBytes,
          filename: 'receipt_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        debugPrint(
          'Cloudinary upload failed (${response.statusCode}): ${response.body}',
        );
        throw 'Failed to upload receipt image';
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final secureUrl = json['secure_url'] as String?;
      return secureUrl;
    } catch (e) {
      debugPrint('Error uploading receipt: $e');
      throw 'Failed to upload receipt image';
    }
  }
}
