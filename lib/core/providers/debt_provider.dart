import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/debt_model.dart';
import '../services/debt_service.dart';
import '../services/notification_trigger_service.dart';
import '../services/offline_cache_service.dart';
import '../utils/date_formatter.dart';

class DebtProvider extends ChangeNotifier {
  DebtProvider({required this.debtService, required this.notificationService});
  final DebtService debtService;
  final NotificationTriggerService notificationService;

  Map<String, List<Debt>> byCollector = {};
  double openTotal = 0;
  double todayOpenTotal = 0;
  Map<String, int> openCountByCollector = {};

  List<Debt> _debts = [];
  StreamSubscription<List<Debt>>? _subscription;
  bool _initialized = false;
  bool _streamDelivered = false;
  int _totalsGeneration = 0;
  bool _totalsHaveData = false;
  final Set<String> _pendingIds = {};
  DateTime? _activeDay;

  List<Debt> get debts => List.unmodifiable(_debts);
  DateTime? get activeDay => _activeDay;
  List<Debt> get openDebts =>
      _debts.where((d) => d.status != DebtStatus.paid).toList();
  List<Debt> debtsForCollector(String collectorId) => _debts
      .where((d) => d.collectorId == collectorId)
      .toList();
  List<Debt> get records {
    final all = _debts;
    final day = _activeDay;
    if (day == null) return all;
    return all
        .where((d) =>
            d.createdAt.year == day.year &&
            d.createdAt.month == day.month &&
            d.createdAt.day == day.day)
        .toList();
  }

  void loadDebtsForDay(DateTime day) {
    _activeDay = day;
    notifyListeners();
  }

  void clearDayFilter() {
    _activeDay = null;
    notifyListeners();
  }

  void initialize() {
    if (_initialized) return;
    _initialized = true;
    _seedFromCache();
    _subscription = debtService.streamAllDebts().listen(
      (debts) {
        _streamDelivered = true;
        _mergeStream(debts);
      },
      onError: (_) {},
    );
    refreshTotals();
  }

  void _mergeStream(List<Debt> fresh) {
    final freshIds = fresh.map((d) => d.id).toSet();
    _pendingIds.removeWhere((id) => freshIds.contains(id));
    final stillPending = _debts
        .where((d) => _pendingIds.contains(d.id) && !freshIds.contains(d.id))
        .toList();
    if (stillPending.isEmpty) {
      _applyAll(fresh);
      return;
    }
    _applyAll([...stillPending, ...fresh]);
  }

  void _seedFromCache() {
    try {
      if (_totalsHaveData) return;
      final cached = OfflineCacheService().getCachedDebts();
      if (cached != null) {
        final sorted = [...cached]
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _debts = sorted;
        _derive(sorted);
      }
      final totals = OfflineCacheService().getCachedDebtTotals();
      if (totals != null) {
        openTotal = totals['openTotal'] ?? openTotal;
        todayOpenTotal = totals['todayOpenTotal'] ?? todayOpenTotal;
        _totalsHaveData = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _derive(List<Debt> all) {
    final open = all.where((d) => d.status != DebtStatus.paid).toList();
    final map = <String, int>{};
    final grouped = <String, List<Debt>>{};
    for (final d in open) {
      map[d.collectorId] = (map[d.collectorId] ?? 0) + 1;
      grouped.putIfAbsent(d.collectorId, () => []).add(d);
    }
    openCountByCollector = map;
    byCollector = grouped;
    final dayStart = DateFormatter.addisDayStart();
    double total = 0, today = 0;
    for (final d in open) {
      total += d.forgivenAmount;
      if (!d.createdAt.isBefore(dayStart)) today += d.forgivenAmount;
    }
    openTotal = total;
    todayOpenTotal = today;
    _totalsHaveData = true;
  }

  Future<void> _persistAll() async {
    try {
      await OfflineCacheService().cacheDebts(_debts);
      await OfflineCacheService().cacheDebtTotals({
        'openTotal': openTotal,
        'todayOpenTotal': todayOpenTotal,
      });
    } catch (_) {}
  }

  void _applyAll(List<Debt> debts) {
    final sorted = [...debts]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _debts = sorted;
    _derive(sorted);
    notifyListeners();
    unawaited(_persistAll());
  }

  Future<Debt> recordDebtFromPurchase({
    required String collectorId,
    required String collectorName,
    required String purchaseId,
    required double totalAmount,
    required double coveredAmount,
    required double forgivenAmount,
    required String createdBy,
    String? notes,
    String source = 'purchase',
    String? linkedName,
    String creditorName = '',
  }) async {
    final debt = await debtService.createDebtFromPurchase(
      collectorId: collectorId,
      collectorName: collectorName,
      purchaseId: purchaseId,
      totalAmount: totalAmount,
      coveredAmount: coveredAmount,
      forgivenAmount: forgivenAmount,
      createdBy: createdBy,
      notes: notes,
      source: source,
      creditorName: creditorName,
    );
    _pendingIds.add(debt.id);
    if (!_debts.any((d) => d.id == debt.id)) {
      _applyAll([debt, ..._debts]);
    }
    await refreshTotals();
    try {
      await notificationService.notifyDebtRecorded(
        collectorId: debt.collectorId,
        collectorName: debt.collectorName,
        forgivenAmount: debt.forgivenAmount,
        totalAmount: debt.totalAmount,
        source: debt.source,
        creditorName: debt.creditorName,
      );
    } catch (_) {}
    notifyListeners();
    return debt;
  }

  Future<void> markPaid(String debtId) async {
    _pendingIds.remove(debtId);
    final previous = _debts;
    _applyAll([
      for (final d in _debts)
        if (d.id == debtId)
          d.copyWith(status: DebtStatus.paid, paidAt: DateTime.now())
        else
          d,
    ]);
    try {
      await debtService.markPaid(debtId);
    } catch (e) {
      _debts = previous;
      _derive(previous);
      notifyListeners();
      rethrow;
    }
    await refreshTotals();
    try {
      Debt? paid;
      for (final d in _debts) {
        if (d.id == debtId) paid = d;
      }
      if (paid == null) {
        for (final d in previous) {
          if (d.id == debtId) paid = d;
        }
      }
      if (paid != null) {
        await notificationService.notifyDebtRepaid(
          collectorId: paid.collectorId,
          collectorName: paid.collectorName,
          amount: paid.forgivenAmount,
        );
      }
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refreshTotals() async {
    final generation = ++_totalsGeneration;
    _seedFromCache();
    List<Debt> server;
    try {
      server = await debtService.getAllDebts();
    } catch (_) {
      return;
    }
    if (generation != _totalsGeneration) return;
    if (!_streamDelivered) {
      _applyAll(server);
    }
  }

  void updateCounts(List<Debt> allOpen) {
    _applyAll(allOpen);
  }

  static double sum(Iterable<Debt> debts) =>
      debts.fold(0.0, (total, d) => total + d.forgivenAmount);

  static double sumToday(Iterable<Debt> debts, {DateTime? now}) {
    final start = DateFormatter.addisDayStart(now);
    final end = start.add(const Duration(days: 1));
    return debts
        .where((d) =>
            d.createdAt.isAfter(start) && d.createdAt.isBefore(end))
        .fold(0.0, (total, d) => total + d.forgivenAmount);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
