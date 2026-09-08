import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/models/debt_model.dart';
import '../../../../core/models/expense_record_model.dart';
import '../../../../core/providers/debt_provider.dart';
import '../../../../core/providers/expense_provider.dart';
import '../../../../core/providers/transaction_provider.dart';
import '../../../../core/providers/income_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/audit_provider.dart';
import '../../../../core/services/expense_service.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../widgets/app_toast.dart';
import '../../../widgets/styled_dropdown.dart';

class AddExpenseDialog extends StatefulWidget {
  final ExpenseRecord? existing;

  const AddExpenseDialog({super.key, this.existing});

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  List<String> _categories = [];
  String? _selectedCategory;
  bool _isSubmitting = false;
  bool _recordAsDebt = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _amountController.text = existing.amount.toStringAsFixed(2);
      _descriptionController.text = existing.description ?? '';
      _selectedCategory = existing.expenseCategory;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await ExpenseService().getExpenseCategories();
    if (mounted) {
      setState(() {
        _categories = categories;
        _selectedCategory ??= categories.isNotEmpty ? categories.first : null;
      });
    }
  }

  double _availableBalance(
      TransactionProvider tp, IncomeProvider ip, ExpenseProvider ep) {
    double moneyIn = ip.totalInvestments + ip.totalSales;
    double moneyOut = ep.totalExpenses;
    for (final t in tp.allTransactions) {
      switch (t.type.toLowerCase()) {
        case 'return':
          moneyIn += t.amount;
          break;
        case 'purchase':
          
          
          
          break;
        case 'distribution':
          moneyOut += t.amount;
          break;
      }
    }
    
    if (widget.existing != null) {
      moneyOut -= widget.existing!.amount;
    }
    final net = moneyIn - moneyOut;
    return net;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final transactionProvider =
        Provider.of<TransactionProvider>(context, listen: false);
    final incomeProvider = Provider.of<IncomeProvider>(context, listen: false);
    final debtProvider = Provider.of<DebtProvider>(context, listen: false);

    final isNew = widget.existing == null;
    final avail =
        _availableBalance(transactionProvider, incomeProvider, provider);
    double? forgiven;
    String? debtNotes;
    final description = _descriptionController.text.trim();
    if (amount > avail + 0.01) {
      if (isNew && _recordAsDebt) {
        forgiven = amount - avail;
        final tag = '[Debt: ETB ${forgiven.toStringAsFixed(0)}]';
        debtNotes = description.isEmpty ? tag : '$description $tag';
      } else {
        if (mounted) {
          AppToast.show(AppLocalizations.of(context)!.insufficientBalance);
        }
        return;
      }
    }

    final record = ExpenseRecord(
      id: widget.existing?.id ?? '',
      amount: amount,
      expenseCategory: _selectedCategory ?? 'Other',
      description: isNew && debtNotes != null
          ? debtNotes
          : (description.isEmpty ? null : description),
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
      createdBy: widget.existing?.createdBy ?? auth.user?.uid ?? 'unknown',
      createdByName:
          widget.existing?.createdByName ?? auth.user?.displayName ?? '',
    );

    setState(() => _isSubmitting = true);
    bool success = false;
    String? expenseId;
    if (!isNew) {
      success = await provider.updateExpense(record);
    } else {
      expenseId = await provider.addExpense(record);
      success = expenseId != null;
    }
    final debtExpenseId = expenseId;
    if (isNew &&
        success &&
        forgiven != null &&
        forgiven > 0 &&
        debtExpenseId != null) {
      try {
        await debtProvider.recordDebtFromPurchase(
          collectorId: Debt.companyCollectorId,
          collectorName: Debt.companyCollectorName,
          purchaseId: debtExpenseId,
          totalAmount: amount,
          coveredAmount: avail,
          forgivenAmount: forgiven,
          createdBy: auth.user?.uid ?? 'unknown',
          notes: debtNotes,
          source: 'expense',
          linkedName: _selectedCategory ?? 'Other',
          creditorName: auth.appUser?.displayName ??
              auth.user?.displayName ??
              '',
        );
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context, true);
        AppToast.show(
          AppLocalizations.of(context)!.expenseRecorded,
          success: true,
        );
        
        
        final auditProvider =
            Provider.of<AuditProvider>(context, listen: false);
        final userName = auth.user?.displayName ?? auth.user?.email ?? '';
        unawaited(auditProvider.logExpenseRecorded(
          userId: auth.user?.uid ?? 'unknown',
          userName: userName,
          expenseId: record.id,
          category: record.expenseCategory,
          amount: amount,
        ));
      } else {
        AppToast.show(provider.errorMessage ?? 'Failed to record expense');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.existing != null ? l10n.editExpense : l10n.addExpense,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: theme.textTheme.headlineMedium?.color,
                  ),
                ),
                const SizedBox(height: 16),
                StyledDropdown<String>(
                  values: _categories,
                  value: _categories.contains(_selectedCategory)
                      ? _selectedCategory
                      : null,
                  label: (c) => c,
                  leading: Icons.category,
                  hint: l10n.selectExpenseCategory,
                  bordered: true,
                  onChanged: (value) =>
                      setState(() => _selectedCategory = value),
                  validator: (value) =>
                      value == null ? l10n.selectExpenseCategory : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: l10n.amountWithCurrency(l10n.currency),
                    prefixIcon: const Icon(Icons.attach_money,
                        color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.amountIsRequired;
                    }
                    final val = double.tryParse(value);
                    if (val == null || val <= 0) return l10n.invalidAmount;
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: l10n.expenseDescription,
                    hintText: l10n.notesOptional,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor:
                        isDark ? Colors.grey.shade800 : Colors.grey.shade50,
                  ),
                ),
                if (widget.existing == null) ...[
                  Builder(builder: (context) {
                    final amt =
                        double.tryParse(_amountController.text.trim()) ?? 0;
                    final avail = _availableBalance(
                      context.watch<TransactionProvider>(),
                      context.watch<IncomeProvider>(),
                      context.watch<ExpenseProvider>(),
                    );
                    final over = amt - avail;
                    if (over <= 0.01) return const SizedBox.shrink();
                    return Container(
                      margin: const EdgeInsets.only(top: 16, bottom: 12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                AppColors.primary.withValues(alpha: 0.18)),
                      ),
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(AppLocalizations.of(context)!.recordExcessAsDebt,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : Colors.black87,
                                fontSize: 14)),
                        subtitle: Text(
                            AppLocalizations.of(context)!.recordExcessSubtitle(avail.toStringAsFixed(0), over.toStringAsFixed(0)),
                            style: TextStyle(
                                fontSize: 12,
                                color: isDark
                                    ? AppColors.textMutedDark
                                    : AppColors.textMutedLight)),
                        value: _recordAsDebt,
                        activeThumbColor: AppColors.primary,
                        onChanged: (v) => setState(() => _recordAsDebt = v),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context)!.currentBalanceInfo(
                            AppLocalizations.of(context)?.currency ?? 'ETB',
                            _availableBalance(
                              Provider.of<TransactionProvider>(context,
                                  listen: false),
                              Provider.of<IncomeProvider>(context,
                                  listen: false),
                              Provider.of<ExpenseProvider>(context,
                                  listen: false),
                            ).formatted,
                          ),
                          style: const TextStyle(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(l10n.confirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
