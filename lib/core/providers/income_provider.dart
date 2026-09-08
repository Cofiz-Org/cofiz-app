import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/income_record_model.dart';
import '../services/income_service.dart';
import '../services/offline_cache_service.dart';
import '../utils/date_formatter.dart';

class IncomeProvider extends ChangeNotifier {
  IncomeProvider({IncomeService? service})
      : _service = service ?? IncomeService();

  final IncomeService _service;

  static const int _pageSize = 20;

  List<IncomeRecord> _records = [];
  bool _isLoading = false;
  String? _errorMessage;

  
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _loadedExtraPages = false;
  StreamSubscription<List<IncomeRecord>>? _subscription;

  
  DateTime? _activeDay;
  int _loadGeneration = 0;

  
  
  
  int _totalsGeneration = 0;

  
  
  
  bool _totalsHaveData = false;

  
  
  final Set<String> _pendingIds = {};

  
  List<IncomeRecord> _fullRecords = [];

  
  double _totalIncome = 0.0;
  double _totalSales = 0.0;
  double _totalInvestments = 0.0;
  double _todayIncome = 0.0;
  double _todaySales = 0.0;
  double _todayInvestments = 0.0;
  int _totalCount = 0;

  List<IncomeRecord> get records => List.unmodifiable(_records);
  List<IncomeRecord> get fullRecords => List.unmodifiable(_fullRecords);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasMoreRecords => _hasMore && _activeDay == null;
  bool get isLoadingMore => _isLoadingMore;
  int get totalRecordCount => _totalCount;
  DateTime? get activeDay => _activeDay;

  List<IncomeRecord> get investments =>
      _records.where((r) => r.kind == IncomeKind.investment).toList();

  List<IncomeRecord> get sales =>
      _records.where((r) => r.kind == IncomeKind.sale).toList();

  double get totalIncome => _totalIncome;
  double get totalInvestments => _totalInvestments;
  double get totalSales => _totalSales;

  double get todayInvestmentIncome => _todayInvestments;
  double get todayManualSales => _todaySales;
  double get todayIncome => _todayIncome;

  
  void initialize() {
    if (_subscription != null) return;
    _subscription = _service.getIncomePageStream(limit: _pageSize).listen(
      (records) {
        _mergeFirstPage(records);
        
        
        if (!_loadedExtraPages) _hasMore = records.length >= _pageSize;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (Object error) {
        _errorMessage = error.toString();
        _isLoading = false;
        notifyListeners();
      },
    );
    _refreshTotals();
  }

  
  void restoreStream() {
    _subscription?.cancel();
    _subscription = null;
    _activeDay = null;
    _loadGeneration++;
    _records = [];
    _lastDoc = null;
    _hasMore = false;
    _isLoadingMore = false;
    _loadedExtraPages = false;
    _isLoading = true;
    notifyListeners();
    initialize();
  }

  
  
  Future<void> loadIncomesForDay(DateTime day) async {
    final generation = ++_loadGeneration;
    _subscription?.cancel();
    _subscription = null;
    _activeDay = day;
    _records = [];
    _lastDoc = null;
    _hasMore = false;
    _isLoadingMore = false;
    _loadedExtraPages = false;
    _isLoading = true;
    notifyListeners();

    final items = await _service.getIncomeForDay(day);
    if (generation != _loadGeneration) return;
    _records = items;
    _totalCount = items.length;
    _isLoading = false;
    notifyListeners();
  }

  
  Future<void> loadMore() async {
    if (_activeDay != null) return;
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();

    
    
    
    var startAfter = _lastDoc;
    if (startAfter == null && _records.isNotEmpty) {
      final bootstrap = await _service.getIncomePage(pageSize: _pageSize);
      startAfter = bootstrap.lastDoc;
      if (startAfter == null) {
        _hasMore = false;
        _isLoadingMore = false;
        notifyListeners();
        return;
      }
    }

    final page = await _service.getIncomePage(
      startAfter: startAfter,
      pageSize: _pageSize,
    );

    if (page.items.isEmpty) {
      _hasMore = false;
      _isLoadingMore = false;
      notifyListeners();
      return;
    }

    final knownIds = _records.map((r) => r.id).toSet();
    _records = [
      ..._records,
      ...page.items.where((r) => !knownIds.contains(r.id)),
    ];
    _lastDoc = page.lastDoc;
    _hasMore = page.hasMore;
    _loadedExtraPages = true;
    _isLoadingMore = false;
    notifyListeners();
  }

  void _mergeFirstPage(List<IncomeRecord> freshHead) {
    if (_activeDay != null) return;

    final freshIds = freshHead.map((r) => r.id).toSet();
    final stillPending = _records
        .where((r) => _pendingIds.contains(r.id) && !freshIds.contains(r.id))
        .toList();
    for (final id in freshIds) {
      if (_pendingIds.remove(id)) {
        unawaited(_refreshTotals());
      }
    }
    if (stillPending.isEmpty) {
      if (!_loadedExtraPages) {
        _records = freshHead;
        _recomputeTotalsFromRecords();
        return;
      }
      final tail = _records.length > freshHead.length
          ? _records.sublist(freshHead.length)
          : <IncomeRecord>[];
      _records = [...freshHead, ...tail];
      _recomputeTotalsFromRecords();
      return;
    }

    final merged = <IncomeRecord>[...stillPending, ...freshHead]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!_loadedExtraPages) {
      _records = merged;
      _recomputeTotalsFromRecords();
      return;
    }
    final tailIds = merged.map((r) => r.id).toSet();
    final tail = _records.where((r) => !tailIds.contains(r.id)).toList();
    _records = [...merged, ...tail];
    _recomputeTotalsFromRecords();
  }

  void _recomputeTotalsFromRecords() {
    final dayStart = DateFormatter.addisDayStart();
    double total = 0, sales = 0, investments = 0;
    double todayIncome = 0, todaySales = 0, todayInvestments = 0;
    for (final r in _records) {
      total += r.amount;
      final isToday = r.createdAt.isAfter(dayStart);
      if (r.kind == IncomeKind.investment) {
        investments += r.amount;
        if (isToday) todayInvestments += r.amount;
      } else {
        sales += r.amount;
        if (isToday) todaySales += r.amount;
      }
      if (isToday) todayIncome += r.amount;
    }
    _totalIncome = total;
    _totalSales = sales;
    _totalInvestments = investments;
    _todayIncome = todayIncome;
    _todaySales = todaySales;
    _todayInvestments = todayInvestments;
    notifyListeners();
  }

  Future<void> _refreshTotals() async {
    final generation = ++_totalsGeneration;
    _seedTotalsFromCache();

    final incomeTotal = await _service.getIncomeTotal();
    final salesTotal = await _service.getIncomeTotalByKind(IncomeKind.sale);
    final investmentsTotal =
        await _service.getIncomeTotalByKind(IncomeKind.investment);
    final todayIncome = await _service.getIncomeTodayTotal();
    final todaySales =
        await _service.getIncomeTodayTotalByKind(IncomeKind.sale);
    final todayInvestments =
        await _service.getIncomeTodayTotalByKind(IncomeKind.investment);
    final count = await _service.getIncomeCount();

    
    
    if (generation != _totalsGeneration) return;

    
    
    
    
    final pendingById = {
      for (final r in _records)
        if (_pendingIds.contains(r.id)) r.id: r,
      for (final r in _fullRecords)
        if (_pendingIds.contains(r.id)) r.id: r,
    };
    final dayStart = DateFormatter.addisDayStart();
    double pendingTotal = 0;
    double pendingSales = 0;
    double pendingInvestments = 0;
    double pendingToday = 0;
    double pendingTodaySales = 0;
    double pendingTodayInvestments = 0;
    for (final r in pendingById.values) {
      pendingTotal += r.amount;
      final isToday = r.createdAt.isAfter(dayStart);
      if (r.kind == IncomeKind.investment) {
        pendingInvestments += r.amount;
        if (isToday) pendingTodayInvestments += r.amount;
      } else {
        pendingSales += r.amount;
        if (isToday) pendingTodaySales += r.amount;
      }
      if (isToday) pendingToday += r.amount;
    }
    debugPrint(
        '[Income] refresh gen=$generation serverTotal=$incomeTotal pending=${pendingById.length} ($pendingTotal)');

    
    
    
    var anyFailed = false;
    if (incomeTotal != null) {
      _totalIncome = incomeTotal + pendingTotal;
    } else {
      anyFailed = true;
    }
    if (salesTotal != null) {
      _totalSales = salesTotal + pendingSales;
    } else {
      anyFailed = true;
    }
    if (investmentsTotal != null) {
      _totalInvestments = investmentsTotal + pendingInvestments;
    } else {
      anyFailed = true;
    }
    if (todayIncome != null) {
      _todayIncome = todayIncome + pendingToday;
    } else {
      anyFailed = true;
    }
    if (todaySales != null) {
      _todaySales = todaySales + pendingTodaySales;
    } else {
      anyFailed = true;
    }
    if (todayInvestments != null) {
      _todayInvestments = todayInvestments + pendingTodayInvestments;
    } else {
      anyFailed = true;
    }
    if (count != null) {
      _totalCount = count + pendingById.length;
    } else {
      anyFailed = true;
    }
    _totalsHaveData = true;

    notifyListeners();

    if (anyFailed) return;

    try {
      await OfflineCacheService().cacheIncomeTotals({
        'totalIncome': _totalIncome,
        'totalSales': _totalSales,
        'totalInvestments': _totalInvestments,
        'todayIncome': _todayIncome,
        'todaySales': _todaySales,
        'todayInvestments': _todayInvestments,
        'totalCount': _totalCount.toDouble(),
      });
    } catch (_) {
      
    }
  }

  void _seedTotalsFromCache() {
    try {
      
      
      
      if (_totalsHaveData) return;
      final cached = OfflineCacheService().getCachedIncomeTotals();
      if (cached == null) return;
      _totalIncome = cached['totalIncome'] ?? 0.0;
      _totalSales = cached['totalSales'] ?? 0.0;
      _totalInvestments = cached['totalInvestments'] ?? 0.0;
      _todayIncome = cached['todayIncome'] ?? 0.0;
      _todaySales = cached['todaySales'] ?? 0.0;
      _todayInvestments = cached['todayInvestments'] ?? 0.0;
      _totalCount = (cached['totalCount'] ?? 0).toInt();
      _totalsHaveData = true;
      notifyListeners();
    } catch (_) {
      
    }
  }

  
  Future<void> loadFullRecords() async {
    try {
      final cached = OfflineCacheService().getCachedIncome();
      if (cached != null) {
        _fullRecords = cached;
        notifyListeners();
      }
    } catch (_) {
      
    }

    final records = await _service.getAllIncome();
    _fullRecords = records;
    try {
      await OfflineCacheService().cacheIncome(records);
    } catch (_) {
      
    }
    notifyListeners();
  }

  Future<bool> addIncome(IncomeRecord record) async {
    final id = await _service.addIncome(record);
    debugPrint('[Income] addIncome queued id=$id amount=${record.amount}');
    if (id == null) {
      _errorMessage = 'Failed to record income';
      notifyListeners();
      return false;
    }
    final optimistic = record.copyWith(id: id);
    if (!_records.any((r) => r.id == id)) {
      _records = [optimistic, ..._records];
    }
    if (!_fullRecords.any((r) => r.id == id)) {
      _fullRecords = [optimistic, ..._fullRecords];
    }
    
    
    
    _totalIncome += optimistic.amount;
    if (optimistic.kind == IncomeKind.investment) {
      _totalInvestments += optimistic.amount;
      _todayInvestments += optimistic.amount;
    } else {
      _totalSales += optimistic.amount;
      _todaySales += optimistic.amount;
    }
    _todayIncome += optimistic.amount;
    _totalCount += 1;
    
    
    _totalsHaveData = true;
    _pendingIds.add(id);
    notifyListeners();
    
    
    _totalsGeneration++;
    _refreshTotals();
    return true;
  }

  Future<bool> updateIncome(IncomeRecord record) async {
    final idx = _records.indexWhere((r) => r.id == record.id);
    final old = idx >= 0 ? _records[idx] : null;
    final fullIdx = _fullRecords.indexWhere((r) => r.id == record.id);
    final oldFull = fullIdx >= 0 ? _fullRecords[fullIdx] : null;

    
    
    _records = [for (final r in _records) r.id == record.id ? record : r];
    _fullRecords = [
      for (final r in _fullRecords) r.id == record.id ? record : r,
    ];
    notifyListeners();

    final success = await _service.updateIncome(record);
    if (!success) {
      
      if (old != null) {
        _records = [
          for (final r in _records) r.id == old.id ? old : r,
        ];
      }
      if (oldFull != null) {
        _fullRecords = [
          for (final r in _fullRecords) r.id == oldFull.id ? oldFull : r,
        ];
      }
      _errorMessage = 'Failed to update income';
      notifyListeners();
      return false;
    }
    _refreshTotals();
    return true;
  }

  Future<bool> deleteIncome(String id) async {
    
    
    
    
    await OfflineCacheService().removePendingOperationByOpId(id);
    _pendingIds.remove(id);

    
    
    
    final removed = <String, IncomeRecord>{};
    for (final r in [..._records, ..._fullRecords]) {
      if (r.id != id || removed.containsKey(r.id)) continue;
      removed[r.id] = r;
    }
    _records = _records.where((r) => r.id != id).toList();
    _fullRecords = _fullRecords.where((r) => r.id != id).toList();
    
    
    _totalsGeneration++;
    _totalsHaveData = true;
    
    
    
    final dayStart = DateFormatter.addisDayStart();
    for (final r in removed.values) {
      _totalIncome -= r.amount;
      final isToday = r.createdAt.isAfter(dayStart);
      if (r.kind == IncomeKind.investment) {
        _totalInvestments -= r.amount;
        if (isToday) _todayInvestments -= r.amount;
      } else {
        _totalSales -= r.amount;
        if (isToday) _todaySales -= r.amount;
      }
      if (isToday) _todayIncome -= r.amount;
      _totalCount -= 1;
    }
    debugPrint(
        '[Income] deleteIncome id=$id remaining records=${_records.length} total=$_totalIncome');
    notifyListeners();

    final success = await _service.deleteIncome(id);
    debugPrint('[Income] deleteIncome id=$id serverSuccess=$success');
    if (!success) {
      
      return false;
    }
    try {
      await OfflineCacheService().removeCachedIncome(id);
    } catch (_) {
      
    }
    _totalsGeneration++;
    _refreshTotals();
    return true;
  }

  static double sum(Iterable<IncomeRecord> records) =>
      records.fold(0.0, (total, r) => total + r.amount);

  static double sumToday(Iterable<IncomeRecord> records, {DateTime? now}) {
    final start = DateFormatter.addisDayStart(now);
    final end = start.add(const Duration(days: 1));
    return records
        .where((r) => r.createdAt.isAfter(start) && r.createdAt.isBefore(end))
        .fold(0.0, (total, r) => total + r.amount);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
