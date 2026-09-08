import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/transaction_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/income_provider.dart';
import '../../../core/providers/expense_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../widgets/eth_date_picker_dialog.dart';
import '../../widgets/debt_tag_notes.dart';
import '../../widgets/styled_dropdown.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/models/user_model.dart';
import '../../widgets/ping_admin_sheet.dart';
import '../../../core/models/transaction_model.dart';
import '../../../core/models/debt_model.dart';
import '../../../core/models/income_record_model.dart';
import '../../../core/models/expense_record_model.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/number_formatter.dart';
import '../../widgets/custom_header.dart';
import '../../widgets/offline_indicator.dart';
import '../../../core/services/report_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/transfer_pair_card.dart';

enum _ReportKind {
  distribution,
  returnMoney,
  purchase,
  transfer,
  investment,
  sale,
  expense
}

class _ReportEntry {
  final _ReportKind kind;
  final DateTime createdAt;
  final Object payload;
  const _ReportEntry(this.kind, this.createdAt, this.payload);
}

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String? _dateFilter;
  String? _typeFilter;
  int _itemsToShow = 20; 
  static const int _itemsPerLoad = 20;
  DateTime? _selectedDate; 
  bool _showCashFlow = false;

  late List<String> _dateOptions;
  late List<String> _typeOptions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context)!;

    _dateOptions = [
      l10n.today,
      l10n.last7Days,
      l10n.thisMonth,
      l10n.allTime,
      l10n.chooseDate
    ];

    _typeOptions = [
      l10n.all,
      l10n.distribute,
      l10n.returnMoney,
      l10n.coffeePurchase,
      l10n.investment,
      l10n.sale,
      l10n.expenses,
    ];

    
    if (_dateFilter == null || !_dateOptions.contains(_dateFilter)) {
      _dateFilter = l10n.allTime;
    }

    if (_typeFilter == null || !_typeOptions.contains(_typeFilter)) {
      _typeFilter = l10n.all;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TransactionProvider>(context, listen: false)
          .loadAllTransactions();
      Provider.of<IncomeProvider>(context, listen: false).loadFullRecords();
      Provider.of<ExpenseProvider>(context, listen: false).loadFullRecords();
    });
  }

  void _loadMore() {
    setState(() {
      _itemsToShow += _itemsPerLoad;
    });
  }

  Future<void> _pickDate() async {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsProvider>(context, listen: false);

    final DateTime? picked;
    if (settings.calendarType == CalendarType.ethiopian) {
      picked = await showEthDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
    } else {
      picked = await showThemedDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now(),
      );
    }

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateFilter = l10n.chooseDate;
        _itemsToShow = _itemsPerLoad; 
      });
    }
  }

  List<_ReportEntry> _getFilteredEntries(
    List<MoneyTransaction> allTransactions,
    List<IncomeRecord> incomeRecords,
    List<ExpenseRecord> expenseRecords,
    AppLocalizations l10n,
  ) {
    DateTime now = DateTime.now();
    DateTime? startDate;
    DateTime? endDate;

    
    if (_dateFilter == l10n.today) {
      startDate = DateFormatter.addisDayStart(now);
    } else if (_dateFilter == l10n.last7Days) {
      startDate = now.subtract(const Duration(days: 7));
    } else if (_dateFilter == l10n.thisMonth) {
      startDate = DateFormatter.addisMonthStart(now);
    } else if (_dateFilter == l10n.allTime) {
      startDate = null;
    } else if (_dateFilter == l10n.chooseDate) {
      if (_selectedDate != null) {
        startDate = DateTime(
            _selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
        endDate = DateTime(_selectedDate!.year, _selectedDate!.month,
            _selectedDate!.day, 23, 59, 59);
      }
    }

    bool dateMatch(DateTime createdAt) {
      if (_dateFilter == l10n.chooseDate &&
          startDate != null &&
          endDate != null) {
        
        return createdAt
                .isAfter(startDate.subtract(const Duration(seconds: 1))) &&
            createdAt.isBefore(endDate.add(const Duration(seconds: 1)));
      }
      return startDate == null || createdAt.isAfter(startDate);
    }

    bool typeMatch(_ReportKind kind) {
      if (_typeFilter == l10n.all) return true;
      switch (_typeFilter) {
        case _ when _typeFilter == l10n.distribute:
          return kind == _ReportKind.distribution;
        case _ when _typeFilter == l10n.returnMoney:
          return kind == _ReportKind.returnMoney;
        case _ when _typeFilter == l10n.coffeePurchase:
          return kind == _ReportKind.purchase;
        case _ when _typeFilter == l10n.investment:
          return kind == _ReportKind.investment;
        case _ when _typeFilter == l10n.sale:
          return kind == _ReportKind.sale;
        case _ when _typeFilter == l10n.expenses:
          return kind == _ReportKind.expense;
        default:
          return false;
      }
    }

    final entries = <_ReportEntry>[
      for (final t in allTransactions)
        _ReportEntry(
          t.isTransfer
              ? _ReportKind.transfer
              : t.type.toLowerCase() == 'return'
                  ? _ReportKind.returnMoney
                  : t.type.toLowerCase() == 'purchase'
                      ? _ReportKind.purchase
                      : _ReportKind.distribution,
          t.createdAt,
          t,
        ),
      for (final r in incomeRecords)
        _ReportEntry(
          r.kind == IncomeKind.sale ? _ReportKind.sale : _ReportKind.investment,
          r.createdAt,
          r,
        ),
      for (final e in expenseRecords)
        _ReportEntry(_ReportKind.expense, e.createdAt, e),
    ];

    return entries
        .where((e) => dateMatch(e.createdAt) && typeMatch(e.kind))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Widget build(BuildContext context) {
    final transactionProvider = Provider.of<TransactionProvider>(context);
    final incomeProvider = Provider.of<IncomeProvider>(context);
    final expenseProvider = Provider.of<ExpenseProvider>(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;
    final entries = _getFilteredEntries(
      transactionProvider.allTransactions,
      incomeProvider.fullRecords,
      expenseProvider.fullRecords,
      l10n,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          
          CustomHeader(
            height: 200, 
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.of(context)?.reports ?? 'Reports',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            if (!auth.isViewer) return const SizedBox.shrink();
                            return IconButton(
                              onPressed: () => showPingAdminSheet(context, UserRole.viewer),
                              icon: const Icon(Icons.send_rounded, color: Colors.white),
                              tooltip: AppLocalizations.of(context)?.pingAdmin ?? 'Ping Admin',
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              style: IconButton.styleFrom(
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            );
                          },
                        ),
                        if (Provider.of<AuthProvider>(context).isViewer)
                          const SizedBox(width: 12),
                        IconButton(
                          onPressed: () async {
                            if (entries.isEmpty) {
                              AppToast.show(
                                  AppLocalizations.of(context)!.noDataToExport);
                              return;
                            }

                            final l10n = AppLocalizations.of(context)!;
                            final errorMsg = l10n.errorGeneratingReport;
                            try {
                              AppToast.show(
                                  l10n.preparingPdfReport);

                              await ReportService().generateTransactionReport(
                                _transactionsFrom(entries),
                                _incomeFrom(entries),
                                _expensesFrom(entries),
                                _dateFilter!,
                                _typeFilter!,
                              );
                            } catch (e, stackTrace) {
                              debugPrint('Error generating PDF report: $e');
                              debugPrint('$stackTrace');
                              if (mounted) {
                                AppToast.show(
                                    '$errorMsg: $e');
                              }
                            }
                          },
                      icon:
                          const Icon(Icons.picture_as_pdf, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      style: IconButton.styleFrom(
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                
                Row(
                  children: [
                    Expanded(
                      child: _selectedDate != null
                          ? _buildDateChip()
                          : _buildFilterDropdown(
                              value: _dateFilter!,
                              items: _dateOptions,
                              onChanged: (val) {
                                if (val == l10n.chooseDate) {
                                  _pickDate();
                                } else {
                                  setState(() {
                                    _dateFilter = val!;
                                    _selectedDate = null;
                                    _itemsToShow = _itemsPerLoad;
                                  });
                                }
                              },
                              icon: Icons.calendar_today,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildFilterDropdown(
                        value: _typeFilter!,
                        items: _typeOptions,
                        onChanged: (val) => setState(() => _typeFilter = val!),
                        icon: Icons.filter_list,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          
          const OfflineIndicator(),

          
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                final txnProvider = Provider.of<TransactionProvider>(context, listen: false);
                final incomeProvider = Provider.of<IncomeProvider>(context, listen: false);
                final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
                txnProvider.loadAllTransactions();
                await incomeProvider.loadFullRecords();
                if (!mounted) return;
                await expenseProvider.loadFullRecords();
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    
                    _buildQuickStats(_transactionsFrom(entries)),

                    const SizedBox(height: 24),

                    
                    if (_typeFilter == l10n.all ||
                        _typeFilter == l10n.coffeePurchase)
                      _buildCoffeeSummary(_transactionsFrom(entries)),

                    const SizedBox(height: 24),

                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Text(
                              _showCashFlow
                                  ? AppLocalizations.of(context)!.cashFlow
                                  : AppLocalizations.of(context)!.transactions,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textTheme.bodyLarge?.color,
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: () => setState(
                                  () => _showCashFlow = !_showCashFlow),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: _showCashFlow
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.swap_horiz,
                                  size: 22,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${entries.length} ${AppLocalizations.of(context)!.records}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textMutedDark
                                : AppColors.textMutedLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    if (entries.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey.shade300),
                              const SizedBox(height: 16),
                              Text(
                                AppLocalizations.of(context)!
                                    .noTransactionsFound,
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (_showCashFlow)
                      _buildCashFlowTable(entries)
                    else
                      Column(
                        children: [
                          ..._buildReportItems(entries),
                          
                          if (entries.length > _itemsToShow)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: OutlinedButton.icon(
                                onPressed: _loadMore,
                                icon: const Icon(Icons.expand_more),
                                label: Text(
                                  AppLocalizations.of(context)!.loadMore,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  side: BorderSide(
                                      color:
                                          AppColors.primary.withValues(alpha: 0.5)),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            )
                          else if (entries.length > _itemsPerLoad)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                AppLocalizations.of(context)!
                                    .showingAllTransactions(entries.length),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textMutedDark
                                      : AppColors.textMutedLight,
                                ),
                              ),
                            ),
                        ],
                      ),

                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateChip() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormatter.formatDate(_selectedDate!),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedDate = null;
                  _dateFilter =
                      'Last 7 Days'; 
                  _itemsToShow = _itemsPerLoad;
                });
              },
              child: Icon(Icons.close,
                  size: 18,
                  color: isDark
                      ? AppColors.textMutedDark
                      : AppColors.textMutedLight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
    required IconData icon,
  }) {
    return StyledDropdown<String>(
      values: items,
      value: items.contains(value) ? value : null,
      label: (s) => s,
      leading: icon,
      onChanged: onChanged,
    );
  }

  List<MoneyTransaction> _transactionsFrom(List<_ReportEntry> entries) =>
      entries
          .where((e) =>
              e.kind == _ReportKind.distribution ||
              e.kind == _ReportKind.returnMoney ||
              e.kind == _ReportKind.purchase)
          .map((e) => e.payload as MoneyTransaction)
          .toList();

  List<IncomeRecord> _incomeFrom(List<_ReportEntry> entries) => entries
      .where(
          (e) => e.kind == _ReportKind.investment || e.kind == _ReportKind.sale)
      .map((e) => e.payload as IncomeRecord)
      .toList();

  List<ExpenseRecord> _expensesFrom(List<_ReportEntry> entries) => entries
      .where((e) => e.kind == _ReportKind.expense)
      .map((e) => e.payload as ExpenseRecord)
      .toList();

  double _entryAmount(_ReportEntry e) {
    switch (e.kind) {
      case _ReportKind.distribution:
      case _ReportKind.returnMoney:
      case _ReportKind.purchase:
      case _ReportKind.transfer:
        return (e.payload as MoneyTransaction).amount;
      case _ReportKind.investment:
      case _ReportKind.sale:
        return (e.payload as IncomeRecord).amount;
      case _ReportKind.expense:
        return (e.payload as ExpenseRecord).amount;
    }
  }

  String _entryPrefix(_ReportEntry e) {
    switch (e.kind) {
      case _ReportKind.distribution:
      case _ReportKind.expense:
        return '-';
      case _ReportKind.returnMoney:
      case _ReportKind.investment:
      case _ReportKind.sale:
        return '+';
      case _ReportKind.purchase:
      case _ReportKind.transfer:
        return '';
    }
  }

  Widget _buildReportItem(_ReportEntry entry,
      {double bottomMargin = 12, VoidCallback? onTapOverride}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final textColor = isDark ? Colors.white : Colors.black87;
    final mutedColor =
        isDark ? AppColors.textMutedDark : AppColors.textMutedLight;

    IconData icon;
    String title;
    String amount;
    String? weightLabel;
    String? note;
    String? subtitleOverride;
    Color amountColor;

    switch (entry.kind) {
      case _ReportKind.distribution:
        final t = entry.payload as MoneyTransaction;
        icon = Icons.arrow_upward;
        title = '${l10n?.distributed ?? 'Distributed'} · ${t.workerName}';
        amountColor = AppColors.error;
        amount = '-${l10n?.currency ?? 'ETB'} ${t.amount.formatted}';
        note = t.notes;
        break;
      case _ReportKind.returnMoney:
        final t = entry.payload as MoneyTransaction;
        icon = Icons.arrow_downward;
        title = '${l10n?.returned ?? 'Returned'} · ${t.workerName}';
        amountColor = AppColors.success;
        amount = '+${l10n?.currency ?? 'ETB'} ${t.amount.formatted}';
        note = t.notes;
        break;
      case _ReportKind.purchase:
        final t = entry.payload as MoneyTransaction;
        icon = Icons.shopping_cart;
        title = '${l10n?.purchased ?? 'Purchased'} · ${t.workerName}';
        amountColor = Colors.orange;
        amount = '${l10n?.currency ?? 'ETB'} ${t.amount.formatted}';
        if (t.coffeeWeight != null) {
          weightLabel =
              '${NumberFormatter.formatWeightAuto(t.coffeeWeight!, kgUnit: l10n?.kg ?? 'Kg', tonUnit: l10n?.ton ?? 'Ton')}'
              ' • '
              '${l10n?.currency ?? 'ETB'} ${(t.pricePerKg ?? 0).formatted}';
        }
        note = t.notes;
        if (note != null && note.isNotEmpty) {
          subtitleOverride = ' · $note';
        }
        break;
      case _ReportKind.transfer:
        final t = entry.payload as MoneyTransaction;
        icon = Icons.swap_horiz;
        final fromName = t.fromWorkerName;
        final toName = t.toWorkerName;
        title = fromName != null && toName != null
            ? (t.isTransferSender
                ? l10n?.transferredTo(fromName, toName) ??
                    '$fromName transferred to $toName'
                : l10n?.receivedFromName(toName, fromName) ??
                    '$toName received from $fromName')
            : (t.isTransferSender
                ? l10n?.transferredOut ?? 'Transferred Out'
                : l10n?.receivedFrom ?? 'Received From');
        amountColor = AppColors.primary;
        amount = '${l10n?.currency ?? 'ETB'} ${t.amount.formatted}';
        break;
      case _ReportKind.investment:
        final r = entry.payload as IncomeRecord;
        icon = Icons.account_balance;
        amountColor = AppColors.success;
        title = '${l10n?.investment ?? 'Investment'} · '
            '${r.viewerName ?? '-'}';
        amount = '+${l10n?.currency ?? 'ETB'} ${r.amount.formatted}';
        note = r.description;
        break;
      case _ReportKind.sale:
        final r = entry.payload as IncomeRecord;
        icon = Icons.point_of_sale;
        amountColor = AppColors.success;
        title = r.saleCategory ?? (l10n?.sale ?? 'Sale');
        amount = '+${l10n?.currency ?? 'ETB'} ${r.amount.formatted}';
        note = r.description;
        break;
      case _ReportKind.expense:
        final e = entry.payload as ExpenseRecord;
        icon = Icons.receipt_long;
        amountColor = AppColors.error;
        title = e.expenseCategory;
        amount = '-${l10n?.currency ?? 'ETB'} ${e.amount.formatted}';
        note = e.description;
        break;
    }

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTapOverride,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        DateFormatter.formatDateTime(entry.createdAt),
                        style: TextStyle(fontSize: 12, color: mutedColor),
                      ),
                      if (subtitleOverride != null &&
                          Debt.cleanNotes(note).isNotEmpty)
                        Flexible(
                          child: Text(
                            ' · ${Debt.cleanNotes(note)}',
                            style: TextStyle(
                                fontSize: 12, color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (Debt.debtTagAmount(note) != null) ...[
                      DebtTagChip(
                        transactionId:
                            entry.payload is MoneyTransaction
                                ? (entry.payload as MoneyTransaction).id
                                : null,
                        fontSize: 10,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      amount,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                if (weightLabel != null)
                  Text(
                    weightLabel,
                    style: TextStyle(fontSize: 10, color: mutedColor),
                  ),
                if (note != null && note.isNotEmpty && subtitleOverride == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      Debt.cleanNotes(note),
                      style: TextStyle(fontSize: 10, color: mutedColor),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _isTransferPair(_ReportEntry a, _ReportEntry b) {
    if (a.kind != _ReportKind.transfer || b.kind != _ReportKind.transfer) {
      return false;
    }
    final ta = a.payload as MoneyTransaction;
    final tb = b.payload as MoneyTransaction;
    return ta.transferId != null && ta.transferId == tb.transferId;
  }

  List<_ReportEntry> _takeWithPairs(List<_ReportEntry> entries, int limit) {
    final chosen = <_ReportEntry>[];
    for (var i = 0; i < entries.length && chosen.length < limit; i++) {
      chosen.add(entries[i]);
      if (chosen.length >= limit) break;
      if (i + 1 < entries.length &&
          _isTransferPair(entries[i], entries[i + 1])) {
        chosen.add(entries[i + 1]);
        i++;
      }
    }
    return chosen;
  }

  List<Widget> _buildReportItems(List<_ReportEntry> entries) {
    final shown = _takeWithPairs(entries, _itemsToShow);
    final children = <Widget>[];
    var i = 0;
    while (i < shown.length) {
      if (i + 1 < shown.length && _isTransferPair(shown[i], shown[i + 1])) {
        children.add(_buildLinkedPair(shown[i], shown[i + 1]));
        i += 2;
      } else {
        children.add(_buildReportItem(shown[i]));
        i += 1;
      }
    }
    return children;
  }

  Widget _buildLinkedPair(_ReportEntry a, _ReportEntry b) {
    return TransferPairCard<_ReportEntry>(
      first: a,
      second: b,
      buildRow: (item,
              {double bottomMargin = 12, VoidCallback? onTapOverride}) =>
          _buildReportItem(item,
              bottomMargin: bottomMargin, onTapOverride: onTapOverride),
    );
  }

  Widget _buildCashFlowTable(List<_ReportEntry> entries) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        isDark ? AppColors.textMutedDark : AppColors.textMutedLight;
    final textColor = isDark ? Colors.white : Colors.black87;
    final l10n = AppLocalizations.of(context);

    final rows = entries.where((e) => e.kind != _ReportKind.transfer).toList();

    String flowOf(_ReportEntry e) {
      switch (e.kind) {
        case _ReportKind.distribution:
        case _ReportKind.expense:
          return l10n?.moneyOut ?? 'Cash Out';
        case _ReportKind.returnMoney:
        case _ReportKind.investment:
        case _ReportKind.sale:
          return l10n?.moneyIn ?? 'Cash In';
        case _ReportKind.purchase:
        case _ReportKind.transfer:
          return l10n?.neutral ?? 'Neutral';
      }
    }

    Color flowColor(_ReportEntry e) {
      switch (e.kind) {
        case _ReportKind.distribution:
        case _ReportKind.expense:
          return AppColors.error;
        case _ReportKind.returnMoney:
        case _ReportKind.investment:
        case _ReportKind.sale:
          return AppColors.success;
        case _ReportKind.purchase:
        case _ReportKind.transfer:
          return mutedColor;
      }
    }

    String whoAndWhat(_ReportEntry e) {
      final l = l10n;
      switch (e.kind) {
        case _ReportKind.distribution:
          final t = e.payload as MoneyTransaction;
          return '${l?.distributed ?? 'Distributed'} · ${t.workerName}';
        case _ReportKind.returnMoney:
          final t = e.payload as MoneyTransaction;
          return '${l?.returned ?? 'Returned'} · ${t.workerName}';
        case _ReportKind.purchase:
          final t = e.payload as MoneyTransaction;
          return '${l?.purchased ?? 'Purchased'} · ${t.workerName}';
        case _ReportKind.transfer:
          final t = e.payload as MoneyTransaction;
          final fromName = t.fromWorkerName;
          final toName = t.toWorkerName;
          return fromName != null && toName != null
              ? '$fromName → $toName'
              : (l?.transfer ?? 'Transfer');
        case _ReportKind.investment:
          final r = e.payload as IncomeRecord;
          return '${l?.investment ?? 'Investment'} · ${r.viewerName ?? '-'}';
        case _ReportKind.sale:
          final r = e.payload as IncomeRecord;
          return r.saleCategory ?? (l?.sale ?? 'Sale');
        case _ReportKind.expense:
          final r = e.payload as ExpenseRecord;
          return '${r.createdByName.isNotEmpty ? r.createdByName : '-'}'
              ' · ${r.expenseCategory}';
      }
    }

    double net = 0;
    for (final e in rows) {
      switch (e.kind) {
        case _ReportKind.distribution:
        case _ReportKind.expense:
          net -= _entryAmount(e);
          break;
        case _ReportKind.returnMoney:
        case _ReportKind.investment:
        case _ReportKind.sale:
          net += _entryAmount(e);
          break;
        case _ReportKind.purchase:
        case _ReportKind.transfer:
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          
          ...rows.map((e) {
            final flow = flowOf(e);
            final color = flowColor(e);
            final amount = '${_entryPrefix(e)}'
                '${l10n?.currency ?? 'ETB'} ${_entryAmount(e).formatted}';
            final note = e.kind == _ReportKind.expense
                ? (e.payload as ExpenseRecord).description
                : e.kind == _ReportKind.investment || e.kind == _ReportKind.sale
                    ? (e.payload as IncomeRecord).description
                    : (e.payload as MoneyTransaction).notes;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      flow,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          whoAndWhat(e),
                          style: TextStyle(
                              fontSize: 13,
                              color: color,
                              fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormatter.formatDateTime(e.createdAt),
                          style: TextStyle(fontSize: 11, color: mutedColor),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            amount,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                        if (note != null && note.isNotEmpty)
                          Text(
                            Debt.cleanNotes(note),
                            style: TextStyle(fontSize: 10, color: mutedColor),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          if (rows.isNotEmpty) ...[
            const SizedBox(height: 8),
            Divider(
                color: isDark ? Colors.grey.shade700 : Colors.grey.shade300),
            const SizedBox(height: 4),

            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Text(
                      l10n?.netBalance ?? 'Net Balance',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                  const Expanded(flex: 3, child: SizedBox.shrink()),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${net >= 0 ? '+' : '-'}${l10n?.currency ?? 'ETB'} '
                      '${net.abs().formatted}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: net >= 0 ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  
  Widget _buildQuickStats(List<MoneyTransaction> transactions) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    
    final purchases =
        transactions.where((t) => t.type.toLowerCase() == 'purchase').toList();

    
    String topBuyer = '-';
    double avgPrice = 0;
    double totalCommission = 0;

    if (purchases.isNotEmpty) {
      
      Map<String, double> buyerTotals = {};
      for (var t in purchases) {
        buyerTotals[t.workerName] = (buyerTotals[t.workerName] ?? 0) + t.amount;
      }
      topBuyer =
          buyerTotals.entries.reduce((a, b) => a.value > b.value ? a : b).key;

      
      double totalWeight = 0;
      double totalValue = 0;
      for (var t in purchases) {
        if (t.coffeeWeight != null && t.coffeeWeight! > 0) {
          totalWeight += t.coffeeWeight!;
          totalValue += t.amount;
        }
      }
      if (totalWeight > 0) {
        avgPrice = totalValue / totalWeight;
      }

      
      for (var t in purchases) {
        totalCommission += t.commissionAmount ?? 0;
      }
    }

    return Row(
      children: [
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.emoji_events,
            label: AppLocalizations.of(context)?.topBuyer ?? 'Top Buyer',
            value: topBuyer.length > 10
                ? '${topBuyer.substring(0, 10)}...'
                : topBuyer,
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.trending_up,
            label: AppLocalizations.of(context)?.avgPrice ?? 'Avg Price',
            value: '${AppLocalizations.of(context)?.currency ?? 'ETB'} ${avgPrice.formatted}/${AppLocalizations.of(context)?.kg ?? 'Kg'}',
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickStatCard(
            icon: Icons.paid,
            label: AppLocalizations.of(context)?.commission ?? 'Commission',
            value: '${AppLocalizations.of(context)?.currency ?? 'ETB'} ${totalCommission.formatted}',
            color: AppColors.primary,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color:
                  isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  
  Widget _buildCoffeeSummary(List<MoneyTransaction> transactions) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    
    final purchases =
        transactions.where((t) => t.type.toLowerCase() == 'purchase').toList();

    if (purchases.isEmpty) return const SizedBox.shrink();

    
    Map<String, Map<String, double>> coffeeData = {};

    for (var t in purchases) {
      String type = t.coffeeType ?? 'Unknown';
      type = type.isNotEmpty
          ? type[0].toUpperCase() + type.substring(1)
          : 'Unknown';

      coffeeData.putIfAbsent(type, () => {'qty': 0, 'total': 0, 'count': 0});
      coffeeData[type]!['qty'] =
          (coffeeData[type]!['qty'] ?? 0) + (t.coffeeWeight ?? 0);
      coffeeData[type]!['total'] = (coffeeData[type]!['total'] ?? 0) + t.amount;
      coffeeData[type]!['count'] = (coffeeData[type]!['count'] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shopping_cart,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context)?.purchasesByType ??
                    'Coffee Purchases by Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          
          ...coffeeData.entries.map((entry) {
            final type = entry.key;
            final data = entry.value;
            final qty = data['qty'] ?? 0;
            final total = data['total'] ?? 0;
            final avgPrice = qty > 0 ? total / qty : 0;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _getCoffeeTypeColor(type),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(_coffeeTypeLabel(type),
                            style: _valueStyle(isDark)),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      NumberFormatter.formatWeightAuto(qty,
                          kgUnit:
                              AppLocalizations.of(context)?.kg ?? 'Kg',
                          tonUnit:
                              AppLocalizations.of(context)?.ton ?? 'Ton'),
                      style: _valueStyle(isDark),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${AppLocalizations.of(context)?.currency ?? 'ETB'} ${avgPrice.formatted}',
                      style: _valueStyle(isDark),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${AppLocalizations.of(context)?.currency ?? 'ETB'} ${total.formatted}',
                      style: _valueStyle(isDark)
                          .copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  TextStyle _valueStyle(bool isDark) {
    return TextStyle(
      fontSize: 13,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  String _coffeeTypeLabel(String type) {
    final l10n = AppLocalizations.of(context);
    switch (type.toLowerCase()) {
      case 'jenfel':
        return l10n?.jenfel ?? 'Dried';
      case 'yetatebe':
        return l10n?.yetatebe ?? 'Washed';
      case 'special':
        return l10n?.special ?? 'Special';
      default:
        return type;
    }
  }

  Color _getCoffeeTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'jenfel':
        return Colors.brown;
      case 'yetatebe':
        return Colors.orange;
      case 'special':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }
}
