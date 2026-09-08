import 'package:cloud_firestore/cloud_firestore.dart';

enum DebtStatus { open, partial, paid }

class Debt {
  static const String companyCollectorId = 'company';
  static const String companyCollectorName = 'Company';

  final String id;
  final String collectorId;
  final String collectorName;
  final String source;
  final String purchaseId;
  final double totalAmount;
  final double coveredAmount;
  final double forgivenAmount;
  final DebtStatus status;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? notes;
  final String createdBy;
  final String creditorName;

  const Debt({
    required this.id,
    required this.collectorId,
    required this.collectorName,
    this.source = 'purchase',
    required this.purchaseId,
    required this.totalAmount,
    required this.coveredAmount,
    required this.forgivenAmount,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.paidAt,
    this.notes,
    this.creditorName = '',
  });

  String creditorDisplay(String fallback) =>
      creditorName.isNotEmpty ? creditorName : fallback;

  static final RegExp debtTagPattern =
      RegExp(r'\[Debt:?\s*ETB\s*([\d,\.]+)\]');

  static String cleanNotes(String? notes) => (notes ?? '')
      .replaceAll(debtTagPattern, '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  static double? debtTagAmount(String? notes) {
    final match = debtTagPattern.firstMatch(notes ?? '');
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', ''));
  }

  Map<String, dynamic> toFirestore() => {
        'collectorId': collectorId,
        'collectorName': collectorName,
        'source': source,
        'purchaseId': purchaseId,
        'totalAmount': totalAmount,
        'coveredAmount': coveredAmount,
        'forgivenAmount': forgivenAmount,
        'status': status.name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        if (paidAt != null) 'paidAt': paidAt!.millisecondsSinceEpoch,
        if (notes != null) 'notes': notes,
        'createdBy': createdBy,
        if (creditorName.isNotEmpty) 'creditorName': creditorName,
      };

  factory Debt.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return Debt.fromMap(doc.data() ?? {}, id: doc.id);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toFirestore()};

  factory Debt.fromJson(Map<String, dynamic> json) =>
      Debt.fromMap(json, id: json['id'] as String? ?? '');

  factory Debt.fromMap(Map<String, dynamic> data, {String id = ''}) {
    final collectorId = data['collectorId'] as String? ?? '';
    if (collectorId.isEmpty) {
      throw ArgumentError('Debt doc missing collectorId');
    }
    return Debt(
      id: id.isEmpty ? (data['id'] as String? ?? '') : id,
      collectorId: collectorId,
      collectorName: data['collectorName'] as String? ?? '',
      source: data['source'] as String? ?? 'purchase',
      purchaseId: data['purchaseId'] as String? ?? '',
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
      coveredAmount: (data['coveredAmount'] as num?)?.toDouble() ?? 0.0,
      forgivenAmount: (data['forgivenAmount'] as num?)?.toDouble() ?? 0.0,
      status: DebtStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => DebtStatus.open,
      ),
      createdAt: _parseTime(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      paidAt: _parseTime(data['paidAt']),
      notes: data['notes'] as String?,
      createdBy: data['createdBy'] as String? ?? '',
      creditorName: data['creditorName'] as String? ?? '',
    );
  }

  static DateTime? _parseTime(dynamic v) {
    if (v == null) return null;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is double) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
    if (v is Timestamp) return v.toDate();
    return null;
  }

  Debt copyWith({DebtStatus? status, DateTime? paidAt, String? notes, String? creditorName}) {
    return Debt(
      id: id,
      collectorId: collectorId,
      collectorName: collectorName,
      source: source,
      purchaseId: purchaseId,
      totalAmount: totalAmount,
      coveredAmount: coveredAmount,
      forgivenAmount: forgivenAmount,
      status: status ?? this.status,
      createdAt: createdAt,
      paidAt: paidAt ?? this.paidAt,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      creditorName: creditorName ?? this.creditorName,
    );
  }
}
