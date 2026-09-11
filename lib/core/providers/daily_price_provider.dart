import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants/coffee_types.dart';

class DailyPriceProvider with ChangeNotifier {
  final FirebaseFirestore _firestore;
  final String companyId;

  DailyPriceProvider({FirebaseFirestore? firestore, this.companyId = 'cofiz'})
      : _firestore = firestore ?? FirebaseFirestore.instance {
    _ready = _loadToday();
  }

  Map<String, double> _prices = {};
  Map<String, double> _yesterday = {};
  CoffeeType _selectedType = CoffeeType.wet;
  late final Future<void> _ready;

  Map<String, double> get prices => Map.unmodifiable(_prices);
  CoffeeType get selectedType => _selectedType;

  static String addisDateKey([DateTime? now]) {
    final addis = (now ?? DateTime.now()).toUtc().add(const Duration(hours: 3));
    final m = addis.month.toString().padLeft(2, '0');
    final d = addis.day.toString().padLeft(2, '0');
    return '${addis.year}-$m-$d';
  }

  String get todayKey => addisDateKey();

  double? priceFor(CoffeeType type) => _prices[type.name];
  bool isSetFor(CoffeeType type) => _prices.containsKey(type.name);
  double? yesterdayPriceFor(CoffeeType type) => _yesterday[type.name];

  void setSelectedType(CoffeeType type) {
    if (_selectedType == type) return;
    _selectedType = type;
    notifyListeners();
  }

  DocumentReference<Map<String, dynamic>> _doc(String dateKey) => _firestore
      .collection('settings')
      .doc('daily_prices')
      .collection(dateKey)
      .doc(companyId);

  static Map<String, double> _readPrices(Map<String, dynamic>? data) {
    final out = <String, double>{};
    final raw = data?['prices'];
    if (raw is Map) {
      raw.forEach((k, v) {
        final n = (v as num?)?.toDouble();
        if (n != null && n > 0) out[k.toString()] = n;
      });
    }
    return out;
  }

  Future<void> _loadToday() async {
    try {
      final today =
          await _doc(todayKey).get().timeout(const Duration(seconds: 5));
      _prices = _readPrices(today.data());
      final yKey =
          addisDateKey(DateTime.now().subtract(const Duration(days: 1)));
      final y = await _doc(yKey).get().timeout(const Duration(seconds: 5));
      _yesterday = _readPrices(y.data());
    } catch (_) {}
    notifyListeners();
  }

  Future<void> savePrice(
      {required CoffeeType type, required double price, String? setBy}) async {
    if (price <= 0) throw ArgumentError('price must be positive');
    await _ready;
    _prices[type.name] = price;
    notifyListeners();
    try {
      await _doc(todayKey).set({
        'companyId': companyId,
        'prices': {type.name: price},
        if (setBy != null) 'setBy': setBy,
        'setAt': DateTime.now().millisecondsSinceEpoch,
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
