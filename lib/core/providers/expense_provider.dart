import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/expense_record_model.dart';
import '../services/expense_service.dart';
import '../services/offline_cache_service.dart';
import '../utils/date_formatter.dart';

class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider({ExpenseService? service})
      : _service = service ?? ExpenseService();

  final ExpenseService _service;

  static const int _pageSize = 20;

  List<ExpenseRecord> _records = [];
  bool _isLoading = false;
  String? _errorMessage;

  
  DocumentSnapshot<Map<String, dynamic>>? _lastDoc;
  bool _hasMore = false;
  bool _isLoadingMore = false;
  bool _loadedExtraPages = false;
  StreamSubscription<List<ExpenseRecord>>? _subscription;

  
  DateTime? _activeDay;
  int _loadGeneration = 0;

  
  
  int _totalsGeneration = 0;

  
  
  
  bool _totalsHaveData = false;

  
  
  final Set<String> _pendingIds = {};

  
  List<ExpenseRecord> _fullRecords = [];

  
  double _totalExpenses = 0.0;
  double _todayExpenses = 0.0;
  int _totalCount = 0;

  List<ExpenseRecord> get records => List.unmodifiable(_records);
  List<ExpenseRecord> get fullRecords => List.unmodifiable(_fullRecords);
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get hasMoreRecords => _hasMore && _activeDay == null;
  bool get isLoadingMore => _isLoadingMore;
  int get totalRecordCount => _totalCount;
  DateTime? get activeDay => _activeDay;

  double get totalExpenses => _totalExpenses;
  double get todayExpenses => _todayExpenses;

  void initialize() {
    if (_subscription != null) return;
    _subscription = _service.getExpensesPageStream(limit: _pageSize).listen(
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

  
  
  Future<void> loadExpensesForDay(DateTime day) async {
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

    final items = await _service.getExpensesForDay(day);
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

    final page = await _service.getExpensesPage(
      startAfter: _lastDoc,
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

  void _mergeFirstPage(List<ExpenseRecord> freshHead) {
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
          : <ExpenseRecord>[];
      _records = [...freshHead, ...tail];
      _recomputeTotalsFromRecords();
      return;
    }

    final merged = <ExpenseRecord>[...stillPending, ...freshHead]
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
    double total = 0, today = 0;
    for (final r in _records) {
      total += r.amount;
      if (r.createdAt.isAfter(dayStart)) today += r.amount;
    }
    _totalExpenses = total;
    _todayExpenses = today;
    notifyListeners();
  }

  Future<void> _refreshTotals() async {
    final generation = ++_totalsGeneration;
    _seedTotalsFromCache();

    final totalExpenses = await _service.getExpensesTotal();
    final todayExpenses = await _service.getExpensesTodayTotal();
    final count = await _service.getExpensesCount();

    
    if (generation != _totalsGeneration) return;

    
    
    
    final pendingById = {
      for (final r in _records)
        if (_pendingIds.contains(r.id)) r.id: r,
      for (final r in _fullRecords)
        if (_pendingIds.contains(r.id)) r.id: r,
    };
    final dayStart = DateFormatter.addisDayStart();
    double pendingTotal = 0;
    double pendingToday = 0;
    for (final r in pendingById.values) {
      pendingTotal += r.amount;
      if (r.createdAt.isAfter(dayStart)) pendingToday += r.amount;
    }
    debugPrint(
        '[Expense] refresh gen=$generation serverTotal=$totalExpenses pending=${pendingById.length} ($pendingTotal)');

    
    
    
    var anyFailed = false;
    if (totalExpenses != null) {
      _totalExpenses = totalExpenses + pendingTotal;
    } else {
      anyFailed = true;
    }
    if (todayExpenses != null) {
      _todayExpenses = todayExpenses + pendingToday;
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
      await OfflineCacheService().cacheExpenseTotals({
        'totalExpenses': _totalExpenses,
        'todayExpenses': _todayExpenses,
        'totalCount': _totalCount.toDouble(),
      });
    } catch (_) {
      
    }
  }

  void _seedTotalsFromCache() {
    try {
      
      
      if (_totalsHaveData) return;
      final cached = OfflineCacheService().getCachedExpenseTotals();
      if (cached == null) return;
      _totalExpenses = cached['totalExpenses'] ?? 0.0;
      _todayExpenses = cached['todayExpenses'] ?? 0.0;
      _totalCount = (cached['totalCount'] ?? 0).toInt();
      _totalsHaveData = true;
      notifyListeners();
    } catch (_) {
      
    }
  }

  
  Future<void> loadFullRecords() async {
    try {
      final cached = OfflineCacheService().getCachedExpenses();
      if (cached != null) {
        _fullRecords = cached;
        notifyListeners();
      }
    } catch (_) {
      
    }

    final records = await _service.getAllExpenses();
    _fullRecords = records;
    try {
      await OfflineCacheService().cacheExpenses(records);
    } catch (_) {
      
    }
    notifyListeners();
  }

  Future<String?> addExpense(ExpenseRecord record) async {
    final id = await _service.addExpense(record);
    debugPrint('[Expense] addExpense queued id=$id amount=${record.amount}');
    if (id == null) {
      _errorMessage = 'Failed to record expense';
      notifyListeners();
      return null;
    }
    final optimistic = record.copyWith(id: id);
    if (!_records.any((r) => r.id == id)) {
      _records = [optimistic, ..._records];
    }
    if (!_fullRecords.any((r) => r.id == id)) {
      _fullRecords = [optimistic, ..._fullRecords];
    }
    
    _totalExpenses += optimistic.amount;
    _todayExpenses += optimistic.amount;
    _totalCount += 1;
    
    
    _totalsHaveData = true;
    _pendingIds.add(id);
    notifyListeners();
    _totalsGeneration++;
    _refreshTotals();
    return id;
  }

  Future<bool> updateExpense(ExpenseRecord record) async {
    final idx = _records.indexWhere((r) => r.id == record.id);
    final old = idx >= 0 ? _records[idx] : null;
    final fullIdx = _fullRecords.indexWhere((r) => r.id == record.id);
    final oldFull = fullIdx >= 0 ? _fullRecords[fullIdx] : null;

    
    
    _records = [for (final r in _records) r.id == record.id ? record : r];
    _fullRecords = [
      for (final r in _fullRecords) r.id == record.id ? record : r,
    ];
    notifyListeners();

    final success = await _service.updateExpense(record);
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
      _errorMessage = 'Failed to update expense';
      notifyListeners();
      return false;
    }
    _refreshTotals();
    return true;
  }

  Future<bool> deleteExpense(String id) async {
    
    
    await OfflineCacheService().removePendingOperationByOpId(id);
    _pendingIds.remove(id);

    
    
    
    final removed = <String, ExpenseRecord>{};
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
      _totalExpenses -= r.amount;
      if (r.createdAt.isAfter(dayStart)) _todayExpenses -= r.amount;
      _totalCount -= 1;
    }
    debugPrint(
        '[Expense] deleteExpense id=$id remaining records=${_records.length} total=$_totalExpenses');
    notifyListeners();

    final success = await _service.deleteExpense(id);
    debugPrint('[Expense] deleteExpense id=$id serverSuccess=$success');
    if (!success) {
      
      return false;
    }
    try {
      await OfflineCacheService().removeCachedExpense(id);
    } catch (_) {
      
    }
    _totalsGeneration++;
    _refreshTotals();
    return true;
  }

  static double sum(Iterable<ExpenseRecord> records) =>
      records.fold(0.0, (total, r) => total + r.amount);

  static double sumToday(Iterable<ExpenseRecord> records, {DateTime? now}) {
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
